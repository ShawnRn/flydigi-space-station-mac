// Staged edits for the four on-board profiles: load slots, edit a draft locally, Apply (⌘S) writes and
// saves, Revert discards. Reading a slot moves the pad's "current" cursor, so the store re-applies the
// user's chosen slot after every enumeration (docs/protocol.md §4).

import Foundation
import Observation
import FlydigiKit
import FlydigiTransport
import FlydigiHelperProtocol

@MainActor @Observable
final class ProfileStore {
    enum ProfileBank: String, CaseIterable, Hashable {
        case pc
        case switchMode
    }

    struct Slot: Identifiable { let index: UInt8; var config: GamepadConfig; var id: UInt8 { index } }

    var profileBank: ProfileBank = .pc
    var slots: [Slot] = []
    private(set) var pcActiveSlot: UInt8 = UInt8(clamping: min(3, max(0, UserDefaults.standard.integer(forKey: "activeSlot"))))
    /// The slot the pad should run (0…3 for PC bank, 4…7 for Switch NS bank).
    var activeSlot: UInt8 = 0 {
        didSet {
            if activeSlot < 4 {
                pcActiveSlot = activeSlot
                UserDefaults.standard.set(Int(activeSlot), forKey: "activeSlot")
            }
            temporarySlot = nil
        }
    }
    /// Slot currently on the pad (a game rule may have moved it temporarily).
    var shownSlot: UInt8 { temporarySlot ?? activeSlot }
    func displayNumber(for slotIndex: UInt8) -> Int {
        Int(slotIndex >= 4 ? slotIndex - 4 : slotIndex) + 1
    }
    var draft: GamepadConfig?                 // edited copy of the active slot
    /// Set by the Buttons tab's "Edit macro" arrow; the Macros page opens this macro when it appears, then clears it.
    var macroToOpen: Int?
    var isDirty: Bool { guard let d = draft, let s = slots.first(where: { $0.index == activeSlot }) else { return false }; return d.bytes != s.config.bytes }
    var lastError: String?
    var busy = false
    var selectedKey: ControllerKey?           // inspector target

    private unowned let controller: ControllerModel
    init(controller: ControllerModel) { self.controller = controller }
    /// Same wording as ControllerModel for timeouts, so the banner never shows raw transport text.
    private func report(_ e: Error) {
        let text = "\(e)"
        if text.contains("no matching report") || text.contains("timeout") {
            lastError = nil
            // Keep existing profile/UI intact on a single transient RF drop; let ControllerModel escalate only on repeated misses.
            controller.noteTransientTimeout()
        } else {
            lastError = text
        }
    }

    func resetBankOnDisconnect() {
        profileBank = .pc
        slots = []
        draft = nil
        activeSlot = pcActiveSlot
    }

    /// Applies pre-fetched config blobs from a batched XInput snapshot without triggering another USB capture.
    func applySnapshot(current: UInt8, blobs: [[UInt8]]) {
        guard profileBank == .pc else { return }
        let mapped = blobs.enumerated().compactMap { i, b in GamepadConfig(bytes: b).map { Slot(index: UInt8(i), config: $0) } }
        guard !mapped.isEmpty else { return }
        slots = mapped
        activeSlot = current < 4 ? current : pcActiveSlot
        if !isDirty { draft = slots.first { $0.index == activeSlot }?.config }
        lastError = nil
    }

    // MARK: Load

    func loadAll(force: Bool = true) async {
        // Nothing to read while the pad has not answered (receiver with the pad off): stay quiet.
        guard controller.info != nil else { lastError = nil; return }
        guard controller.connection == .dinput || controller.connection == .xinput else {
            // NewXInput (0x37D7) config write/read layout is not yet implemented; keep slots empty cleanly without errors.
            slots = []; draft = nil; lastError = nil; return
        }
        if !force, !slots.isEmpty { return }
        if controller.connection == .xinput, controller.lastSnapshotHandledSlots {
            controller.lastSnapshotHandledSlots = false
            return
        }
        busy = true; defer { busy = false }
        let conn = controller.connection
        let bank = profileBank
        let startSlot: UInt8 = bank == .pc ? 0 : 4
        // Re-apply the active PC slot after reading so reading Switch slots (4…7) or other PC slots never shifts the pad cursor.
        let restorePC = controller.padSlot.flatMap { $0 < 4 ? $0 : nil } ?? pcActiveSlot
        let targetDefault = bank == .pc ? restorePC : (activeSlot >= 4 ? activeSlot : 4)
        let result: Result<(UInt8, [(UInt8, [UInt8])]), Error> = await Task.detached {
            Result {
                switch conn {
                case .dinput:
                    let s = try DeviceSession.open(preferring: .dinput); defer { s.close() }
                    s.configId = targetDefault; _ = try? s.readBlob(.config)
                    var out: [(UInt8, [UInt8])] = []
                    for offset in 0..<UInt8(4) {
                        let id = startSlot + offset
                        s.configId = id
                        out.append((id, try s.readBlob(.config)))
                    }
                    try? s.applyConfig(slot: restorePC)
                    return (targetDefault, out)
                case .xinput:
                    guard #available(macOS 14.0, *) else { throw HelperError.notInstalled }
                    let h = HelperClient.shared
                    _ = try? h.readConfig(slot: targetDefault)
                    var out: [(UInt8, [UInt8])] = []
                    for offset in 0..<UInt8(4) {
                        let id = startSlot + offset
                        out.append((id, try h.readConfig(slot: id)))
                    }
                    try h.applySlot(restorePC)
                    return (targetDefault, out)
                case .none, .newXInput: throw HelperError.transport("no controller")
                }
            }
        }.value
        switch result {
        case .success(let (current, blobs)):
            slots = blobs.compactMap { i, b in GamepadConfig(bytes: b).map { Slot(index: i, config: $0) } }
            if slots.isEmpty { lastError = String(localized: "Could not decode the controller's profiles"); return }
            activeSlot = current
            draft = slots.first { $0.index == activeSlot }?.config
            lastError = nil
            if conn == .dinput || controller.led == nil {
                await controller.loadLED(slot: current)
            }
        case .failure(let e): report(e)
        }
    }

    func switchBank(_ bank: ProfileBank) async {
        guard bank != profileBank, !busy else { return }
        profileBank = bank
        activeSlot = bank == .pc ? pcActiveSlot : 4
        slots = []
        draft = nil
        await loadAll(force: true)
    }

    var isSwitchFaceLayoutActive: Bool {
        guard let keys = draft?.keys else { return false }
        return keys[.a] == .key(.b) && keys[.b] == .key(.a) && keys[.x] == .key(.y) && keys[.y] == .key(.x)
    }

    /// Toggles Nintendo Switch face button swap (`A↔B` and `X↔Y`) on the current draft.
    func toggleSwitchFaceLayout() {
        guard var cfg = draft else { return }
        if isSwitchFaceLayoutActive {
            cfg.keys[.a] = .identity
            cfg.keys[.b] = .identity
            cfg.keys[.x] = .identity
            cfg.keys[.y] = .identity
        } else {
            cfg.keys[.a] = .key(.b)
            cfg.keys[.b] = .key(.a)
            cfg.keys[.x] = .key(.y)
            cfg.keys[.y] = .key(.x)
        }
        draft = cfg
    }

    // MARK: Nintendo Switch mode

    /// "Apply to NS mode": the pad keeps a second set of four profiles (config ids 4…7) used in Switch mode.
    /// Copies the current draft — keyboard/mouse mappings stripped back to identity — plus its lighting into
    /// slot `activeSlot + 4` (for PC slots 0…3) and saves to flash.
    func applyToSwitchMode() async {
        guard var cfg = draft else { return }
        busy = true; defer { busy = false }
        for (k, m) in cfg.keys { if case .keyboardMouse = m { cfg.keys[k] = .identity } }
        let baseSlot = activeSlot < 4 ? activeSlot : (activeSlot - 4)
        let target = baseSlot + 4
        let bytes = cfg.bytes, led = controller.led
        let conn = controller.connection
        let result: Result<Void, Error> = await Task.detached {
            Result {
                switch conn {
                case .dinput:
                    let s = try DeviceSession.open(preferring: .dinput); defer { s.close() }
                    s.configId = target
                    try s.writeBlob(bytes, kind: .config)
                    if let led { try s.writeBlob(led.bytes, kind: .led) }
                    try s.saveToFlash()
                case .xinput:
                    guard #available(macOS 14.0, *) else { throw HelperError.notInstalled }
                    try HelperClient.shared.writeConfig(slot: target, bytes: bytes, persist: true)
                    if let led { try HelperClient.shared.applyLED(led, slot: target, persist: true) }
                case .none, .newXInput: throw HelperError.transport("no controller")
                }
            }
        }.value
        switch result {
        case .success: lastError = nil
        case .failure(let e): report(e)
        }
    }

    // MARK: Follow the pad's own slot switch (SELECT + A/B/X/Y, screen menu)

    private var padSlotWatch: Task<Void, Never>?
    /// DInput only: the HID channel is free, so asking `05 EB A0` every few seconds is harmless. In XInput
    /// a query would borrow the device from games; there the app notices on connect and on Refresh.
    func setPadSlotWatch(_ on: Bool) {
        padSlotWatch?.cancel(); padSlotWatch = nil
        guard on else { return }
        padSlotWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard let self, !self.busy, !self.isDirty, self.controller.connection == .dinput, !self.slots.isEmpty else { continue }
                let cur: UInt8? = await Task.detached { let s = try? DeviceSession.open(preferring: .dinput); defer { s?.close() }; return try? s?.currentConfigId() }.value
                guard let cur, cur < 4, cur != self.activeSlot, self.temporarySlot == nil else { continue }
                self.activeSlot = cur
                self.draft = self.slots.first { $0.index == cur }?.config
                await self.controller.loadLED(slot: cur)
            }
        }
    }

    // MARK: Edit

    func select(slot: UInt8) {
        guard !isDirty || slot == activeSlot else { return }   // UI asks before discarding
        activeSlot = slot
        draft = slots.first { $0.index == slot }?.config
        Task {
            if profileBank == .pc, slot < 4 { await activateOnPad(slot) }
            await controller.loadLED(slot: slot)
        }
    }

    func revert() { draft = slots.first { $0.index == activeSlot }?.config }
    /// Factory values in the draft (apply to write them to the pad).
    func resetToFactory() {
        draft?.resetToFactory()
        // Lighting is part of the profile in Space Station too: back to the factory effect for this slot.
        if var l = controller.led { l.setFactoryDefault(); l.brightness = 50; l.speed = 15; Task { await controller.apply(led: l) } }
    }

    /// Reflect a slot the game-profile watcher activated without changing the remembered choice.
    func showTemporary(slot: UInt8) {
        guard !isDirty else { return }
        temporarySlot = slot
        draft = slots.first { $0.index == slot }?.config
    }
    var temporarySlot: UInt8?

    func setMapping(_ key: ControllerKey, _ mapping: GamepadConfig.KeyMapping) { draft?.keys[key] = mapping }

    // MARK: Macros (on-board; the trigger button's mapping becomes 0x20 "macro", like Space Station does)

    var maxMacros: Int { (draft?.protoVersion ?? 0x0300) >= 770 ? 10 : 5 }
    var macroTick: Int { (draft?.protoVersion ?? 0x0300) >= 770 ? 1 : 10 }      // ms resolution of the timeline

    func macroIndex(for key: ControllerKey) -> Int? { draft?.macros.firstIndex { $0.key == key.rawValue } }

    /// Creates an empty macro bound to `key` (or returns the existing one). `nil` when the slot is full.
    @discardableResult
    func addMacro(for key: ControllerKey) -> Int? {
        // A macro can outlive its binding (the key was switched to Click/Turbo and back): relink instead of adding.
        if let i = macroIndex(for: key) { draft?.keys[key] = .macro; return i }
        guard let d = draft, d.macros.count < maxMacros else { return nil }
        draft?.macros.append(.init(key: key.rawValue, count: 0, enable: .once, actions: []))
        draft?.keys[key] = .macro
        return draft!.macros.count - 1
    }

    func removeMacro(at i: Int) {
        guard let m = draft?.macros[safe: i] else { return }
        draft?.macros.remove(at: i)
        if let k = ControllerKey(rawValue: m.key), case .macro? = draft?.keys[k] { draft?.keys[k] = .identity }
    }

    func updateMacro(at i: Int, _ change: (inout GamepadConfig.Macro) -> Void) {
        guard var m = draft?.macros[safe: i] else { return }
        let oldKey = m.key
        change(&m)
        m.count = m.actions.count
        draft?.macros[i] = m
        if m.key != oldKey {                                     // re-bind the trigger button
            if let k = ControllerKey(rawValue: oldKey), case .macro? = draft?.keys[k] { draft?.keys[k] = .identity }
            if let k = ControllerKey(rawValue: m.key) { draft?.keys[k] = .macro }
        }
    }

    // MARK: Apply

    func apply() async {
        guard var cfg = draft, isDirty else { return }
        if profileBank == .switchMode {
            for (k, m) in cfg.keys { if case .keyboardMouse = m { cfg.keys[k] = .identity } }
            self.draft = cfg
        }
        busy = true; defer { busy = false }
        let conn = controller.connection, slot = activeSlot, bytes = cfg.bytes
        let shouldActivate = profileBank == .pc && slot < 4
        let result: Result<Void, Error> = await Task.detached {
            Result {
                switch conn {
                case .dinput:
                    let s = try DeviceSession.open(preferring: .dinput); defer { s.close() }
                    s.configId = slot
                    try s.writeBlob(bytes, kind: .config); try s.saveToFlash()
                case .xinput:
                    guard #available(macOS 14.0, *) else { throw HelperError.notInstalled }
                    try HelperClient.shared.writeConfig(slot: slot, bytes: bytes, persist: true)
                    if shouldActivate { try HelperClient.shared.applySlot(slot) }
                case .none, .newXInput: throw HelperError.transport("no controller")
                }
            }
        }.value
        switch result {
        case .success:
            if let i = slots.firstIndex(where: { $0.index == slot }), let cfg = GamepadConfig(bytes: bytes) { slots[i].config = cfg; self.draft = cfg }
            lastError = nil
        case .failure(let e): report(e)
        }
    }

    /// Sends the draft with one trigger's adapter block replaced, **without** saving to flash. This is how the
    /// Vibration (grip-sync) mode has to be previewed: the live `A5 30 06/08` commands do not switch the pad
    /// into it, only a profile write does (verified 2026-09-02 — Space Station does the same).
    func previewTrigger(side: Side, adapterType: UInt8, adapterBlock: [UInt8]) async {
        guard var cfg = draft, controller.connection == .xinput else { return }
        var t = cfg[trigger: side]
        t.adapterType = adapterType; t.adapterParams = adapterBlock; t.kind = adapterType == 0 ? .normal : .adapter
        cfg[trigger: side] = t
        let slot = activeSlot, bytes = cfg.bytes
        let r: Result<Void, Error> = await Task.detached {
            Result {
                guard #available(macOS 14.0, *) else { throw HelperError.notInstalled }
                try HelperClient.shared.writeConfig(slot: slot, bytes: bytes, persist: false)
            }
        }.value
        if case .failure(let e) = r { report(e) }
    }

    private func activateOnPad(_ slot: UInt8) async {
        let conn = controller.connection
        _ = await Task.detached {
            Result {
                switch conn {
                case .dinput: let s = try DeviceSession.open(preferring: .dinput); defer { s.close() }; try s.applyConfig(slot: slot)
                case .xinput: if #available(macOS 14.0, *) { try HelperClient.shared.applySlot(slot) }
                case .none, .newXInput: break
                }
            }
        }.value
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
