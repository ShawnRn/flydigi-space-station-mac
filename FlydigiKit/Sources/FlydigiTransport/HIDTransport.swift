// DInput transport: the controller's vendor HID interface (04b4:2412, interface 2, usage page 0xFFA0),
// driven with IOHIDManager. Unprivileged.

import Foundation
import IOKit.hid
import FlydigiKit

public enum TransportError: Error, CustomStringConvertible {
    case notFound(String)
    case io(String)
    case timeout(String)
    case protocolError(String)
    public var description: String {
        switch self {
        case .notFound(let s), .io(let s), .timeout(let s), .protocolError(let s): return s
        }
    }
}

/// A byte-level link to the controller: write a packet, receive reports.
public protocol Link: AnyObject, Sendable {
    var channel: Channel { get }
    func write(_ packet: [UInt8]) throws
    /// Waits up to `timeout` for a report satisfying `match`; returns its result.
    func waitForReport<T>(timeout: TimeInterval, _ match: @Sendable @escaping ([UInt8]) -> T?) throws -> T
    func close()
    /// Drop reports received so far (before issuing a new request).
    func discardPending()
    /// Close without resetting/re-enumerating the device (use right after a mode-switch command,
    /// which makes the controller re-enumerate on its own — a reset would abort the switch).
    func closeWithoutReset()
}

public extension Link { func closeWithoutReset() { close() }; func discardPending() {} }

public final class HIDLink: Link, @unchecked Sendable {
    public let channel: Channel = .dinput
    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let queue = DispatchQueue(label: "flydigi.hid")
    private let lock = NSLock()
    private var inbox: [[UInt8]] = []
    private let arrived = DispatchSemaphore(value: 0)
    private let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)

    /// Opens the vendor interface of the first Apex 4 found in DInput mode.
    public init() throws {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: Int(USBID.dinputVendor),
            kIOHIDProductIDKey: Int(USBID.dinputProduct),
            kIOHIDPrimaryUsagePageKey: Int(USBID.dinputVendorUsagePage),
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let dev = set.first else {
            throw TransportError.notFound("Apex 4 not found in DInput mode (04b4:2412). Plug it in over USB and switch to DInput.")
        }
        device = dev
        guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            throw TransportError.io("IOHIDDeviceOpen failed")
        }
        // Dispatch-queue based delivery (no run loop needed — works in the app, the CLI and the daemon).
        IOHIDDeviceSetDispatchQueue(device, queue)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        do {
            IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, 64, { ctx, _, _, _, reportId, report, length in
                let me = Unmanaged<HIDLink>.fromOpaque(ctx!).takeUnretainedValue()
                // For devices with numbered reports IOHIDManager already delivers the report id as byte 0
                // (same layout as hidapi), so the buffer is used as-is.
                _ = reportId
                let bytes = Array(UnsafeBufferPointer(start: report, count: Int(length)))
                me.lock.lock(); me.inbox.append(bytes); if me.inbox.count > 512 { me.inbox.removeFirst() }; me.lock.unlock()
                me.arrived.signal()
            }, ctx)
        }
        IOHIDDeviceActivate(device)
    }

    public func write(_ packet: [UInt8]) throws {
        // Like hidapi on macOS: the buffer handed to IOHIDDeviceSetReport keeps the report-id byte in
        // front — that is the byte layout the Flydigi firmware expects (verified: stripping it gets no reply).
        let id = CFIndex(packet[0])
        let r = packet.withUnsafeBufferPointer { IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, id, $0.baseAddress!, $0.count) }
        guard r == kIOReturnSuccess else { throw TransportError.io(String(format: "IOHIDDeviceSetReport failed: 0x%08x", r)) }
    }

    public func waitForReport<T>(timeout: TimeInterval, _ match: @Sendable @escaping ([UInt8]) -> T?) throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            lock.lock()
            while !inbox.isEmpty {
                let r = inbox.removeFirst()
                if let v = match(r) { lock.unlock(); return v }
            }
            lock.unlock()
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { throw TransportError.timeout("no matching report within \(timeout)s") }
            _ = arrived.wait(timeout: .now() + remaining)
        }
    }

    public func discardPending() { lock.lock(); inbox.removeAll(); lock.unlock() }

    public func close() {
        guard !closed else { return }
        closed = true
        IOHIDDeviceCancel(device)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    deinit {
        reportBuffer.deallocate()
    }
    private var closed = false
}

// MARK: - NewXInput (0x37D7) read-only probe over unprivileged vendor HID

public enum NewXInputProbe {
    /// Checks if any Flydigi `0x37D7` device exposes the `0xFFA0` vendor HID and reads its `5A A5 01` info.
    public static func probeDeviceInfo(timeout: TimeInterval = 1.5) throws -> DeviceInfo {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: Int(USBID.newXInputVendor),
            kIOHIDPrimaryUsagePageKey: Int(USBID.dinputVendorUsagePage),
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let dev = set.first else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw TransportError.notFound("No 0x37D7 Flydigi HID vendor interface found.")
        }
        defer {
            IOHIDDeviceCancel(dev)
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        guard IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            throw TransportError.io("IOHIDDeviceOpen failed on 0x37D7 vendor interface")
        }

        final class Collector: @unchecked Sendable {
            let lock = NSLock()
            var info: DeviceInfo?
            let arrived = DispatchSemaphore(value: 0)
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
            deinit { buf.deallocate() }
        }
        let col = Collector()
        let queue = DispatchQueue(label: "flydigi.newxinput.probe")
        IOHIDDeviceSetDispatchQueue(dev, queue)
        let ctx = Unmanaged.passUnretained(col).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(dev, col.buf, 64, { ctx, _, _, _, _, report, length in
            let c = Unmanaged<Collector>.fromOpaque(ctx!).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: Int(length)))
            if let parsed = NewXInputReply.deviceInfo(bytes) {
                c.lock.lock(); c.info = parsed; c.lock.unlock()
                c.arrived.signal()
            }
        }, ctx)
        IOHIDDeviceActivate(dev)

        // Try reportId 3 (Apex 5) only if descriptor max output < 32? Actually per docs/adding-a-controller.md §4:
        // Vader 5 Pro declares no report id (use report 0); Apex 5 declares report id 3.
        let pid = (IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? 0
        let reportIds: [UInt8?] = (pid == 0x2501) ? [0x03, nil] : [nil, 0x03]
        for rid in reportIds {
            let pkt = NewXInput.heartbeat(reportId: rid)
            let id = CFIndex(rid ?? 0)
            let kr = pkt.withUnsafeBufferPointer { IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, id, $0.baseAddress!, $0.count) }
            if kr == kIOReturnSuccess {
                _ = col.arrived.wait(timeout: .now() + timeout / Double(reportIds.count))
                col.lock.lock(); let res = col.info; col.lock.unlock()
                if let res { return res }
            }
        }
        throw TransportError.timeout("No NewXInput heartbeat reply within \(timeout)s")
    }
}
