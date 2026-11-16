// The controller on the stage. The outline and product picture come from Space Station 4's assets
// (see Resources/Flydigi/NOTICE.md); the hotspot geometry is Space Station's `device_config_k2`
// (508 × 421 canvas), so buttons land exactly on the drawing. Falls back to a schematic when the files
// are missing.

import SwiftUI
import AppKit
import FlydigiKit

struct Hotspot: Identifiable, Hashable {
    enum Shape: Hashable { case circle, roundRect, rect }
    let key: ControllerKey
    let rect: CGRect                    // in canvas coordinates (Apex4Render.canvas)
    var shape: Shape = .rect
    var rotation: Double = 0            // degrees
    var clickable = true
    var id: UInt8 { key.rawValue }
    var label: String { Apex4Render.shortLabel(key) }
    func label(switchMode: Bool) -> String { Apex4Render.shortLabel(key, switchMode: switchMode) }
    var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }

    init(_ key: ControllerKey, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ shape: Shape = .rect, rotation: Double = 0, clickable: Bool = true) {
        self.key = key; rect = CGRect(x: x, y: y, width: w, height: h); self.shape = shape; self.rotation = rotation; self.clickable = clickable
    }
}

enum Apex4Render {
    static let canvas = CGSize(width: 508, height: 421)

    /// Mapping targets for Apex 4, in drawing order. Same positions/sizes as Space Station 4 (`device_config_k2`).
    static let hotspots: [Hotspot] = [
        .init(.lt, 6, 3, 40, 48), .init(.rt, 460, 3, 40, 48),
        .init(.lb, 9, 51, 75, 28), .init(.rb, 423, 51, 75, 28),
        .init(.select, 166, 108, 40, 18, .roundRect, rotation: 49), .init(.start, 301, 108, 40, 18, .roundRect, rotation: -51),
        .init(.thumbL, 116.5, 152.5, 32, 32, .circle), .init(.thumbR, 302, 216, 32, 32, .circle),
        .init(.y, 364, 130, 32, 32, .circle), .init(.x, 335, 159, 32, 32, .circle), .init(.b, 393, 159, 32, 32, .circle), .init(.a, 364, 188, 32, 32, .circle),
        .init(.up, 186, 194, 24, 24, .circle), .init(.right, 212, 222, 24, 24, .circle), .init(.down, 186, 250, 24, 24, .circle), .init(.left, 158, 222, 24, 24, .circle),
        .init(.menu, 225, 275, 28, 12, .roundRect, clickable: false), .init(.home, 260, 275, 28, 12, .roundRect, clickable: false),
        .init(.m2, 149, 344, 41, 41), .init(.m4, 206, 344, 41, 41), .init(.m3, 263, 344, 41, 41), .init(.m1, 324, 345, 41, 41),
    ]

    /// Mapping targets adapted to the connected controller's actual physical buttons.
    static func hotspots(for family: DeviceDescriptor.Family, capabilities: DeviceDescriptor.Capabilities) -> [Hotspot] {
        switch family {
        case .direwolf4, .direwolf3:
            return [
                .init(.lt, 6, 3, 40, 48), .init(.rt, 460, 3, 40, 48),
                .init(.lb, 9, 51, 75, 28), .init(.rb, 423, 51, 75, 28),
                .init(.select, 184, 148, 40, 18, .roundRect, rotation: 41), .init(.start, 284, 148, 40, 18, .roundRect, rotation: -41),
                .init(.thumbL, 116.5, 152.5, 32, 32, .circle), .init(.thumbR, 307, 223, 32, 32, .circle),
                .init(.y, 364, 130, 32, 32, .circle), .init(.x, 335, 159, 32, 32, .circle), .init(.b, 393, 159, 32, 32, .circle), .init(.a, 364, 188, 32, 32, .circle),
                .init(.up, 186, 196, 24, 24, .circle), .init(.right, 212, 222, 24, 24, .circle), .init(.down, 186, 248, 24, 24, .circle), .init(.left, 160, 222, 24, 24, .circle),
                .init(.menu, 225, 275, 28, 12, .roundRect, clickable: false), .init(.home, 260, 275, 28, 12, .roundRect, clickable: false),
                .init(.m2, 160, 345, 41, 41), .init(.m1, 300, 344, 41, 41),
            ]
        case .vader4pro, .vader3, .vader5:
            return [
                .init(.lt, 6, 3, 40, 48), .init(.rt, 460, 3, 40, 48),
                .init(.lb, 9, 51, 75, 28), .init(.rb, 423, 51, 75, 28),
                .init(.select, 171, 118, 40, 18, .roundRect, rotation: 41), .init(.start, 296, 118, 40, 18, .roundRect, rotation: -41),
                .init(.thumbL, 116.5, 152.5, 32, 32, .circle), .init(.thumbR, 301, 217, 32, 32, .circle),
                .init(.y, 364, 130, 32, 32, .circle), .init(.x, 335, 159, 32, 32, .circle), .init(.b, 393, 159, 32, 32, .circle), .init(.a, 364, 188, 32, 32, .circle),
                .init(.c, 379, 239, 26, 26, .circle), .init(.z, 408, 210, 26, 26, .circle),
                .init(.up, 186, 194, 24, 24, .circle), .init(.right, 212, 222, 24, 24, .circle), .init(.down, 186, 250, 24, 24, .circle), .init(.left, 158, 222, 24, 24, .circle),
                .init(.menu, 225, 275, 28, 12, .roundRect, clickable: false), .init(.home, 260, 275, 28, 12, .roundRect, clickable: false),
                .init(.m2, 149, 344, 41, 41), .init(.m4, 206, 344, 41, 41), .init(.m3, 263, 344, 41, 41), .init(.m1, 324, 345, 41, 41),
            ]
        default:
            if capabilities.backPaddles <= 2 && !capabilities.hasCZButtons {
                return hotspots.filter { $0.key != .m3 && $0.key != .m4 }
            }
            return hotspots
        }
    }

    static func stickWells(for family: DeviceDescriptor.Family) -> [CGRect] {
        switch family {
        case .direwolf4, .direwolf3:
            return [CGRect(x: 100, y: 136, width: 65, height: 65), CGRect(x: 290, y: 206, width: 65, height: 65)]
        default:
            return stickWells
        }
    }

    /// Stick wells (decorative rings under the stick-click chips).
    static let stickWells: [CGRect] = [CGRect(x: 100, y: 136, width: 65, height: 65), CGRect(x: 285, y: 200, width: 65, height: 65)]

    /// Keys the user can point at (physical buttons the firmware lets you remap).
    static var mappableKeys: [ControllerKey] { hotspots.filter(\.clickable).map(\.key) }

    static func mappableKeys(for family: DeviceDescriptor.Family, capabilities: DeviceDescriptor.Capabilities) -> [ControllerKey] {
        hotspots(for: family, capabilities: capabilities).filter(\.clickable).map(\.key)
    }

    static func shortLabel(_ k: ControllerKey, switchMode: Bool = false) -> String {
        if switchMode {
            switch k {
            case .lt: return "ZL"
            case .rt: return "ZR"
            case .lb: return "L"
            case .rb: return "R"
            case .select: return "−"
            case .start: return "+"
            case .back: return "⊡"
            case .home: return "⌂"
            case .c: return "C"
            default: break
            }
        }
        switch k {
        case .up: return "▲"; case .down: return "▼"; case .left: return "◀"; case .right: return "▶"
        case .thumbL: return "LS"; case .thumbR: return "RS"; case .select: return "⧉"; case .start: return "≡"; case .home: return "⌂"; case .menu: return "Fn"
        default: return "\(k)".uppercased()
        }
    }

    // MARK: Artwork

    static let wireframe: NSImage? = load("apex4-wireframe", "svg")
    static let hero: NSImage? = load("k2-84", "png")
    /// Space Station's device-card artwork for the special editions (EVA-01, Assassin's Creed, Black Myth
    /// Wukong, Genshin, Honkai Star Rail); the standard Apex 4 has none.
    static func cardBackground(deviceId: UInt8?) -> NSImage? { deviceId.flatMap { load("card-k2-\($0)", "png") } }
    /// Space Station's "add device" silhouette shown when nothing is connected.
    static let addDevice: NSImage? = load("add-device", "png")
    /// Product picture for a specific Apex 4 variant (Space Station's `k2/<id>/main.png`), falling back to the base model.
    static func productImage(deviceId: UInt8?) -> NSImage? {
        if let id = deviceId, let img = load("k2-\(id)", "png") { return img }
        return hero
    }

    private static func load(_ name: String, _ ext: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return NSImage(contentsOf: url)
    }
}

/// The outline drawing, scaled to fit while keeping the 508 × 421 canvas aspect.
/// Models with an on-board screen use the Apex wireframe; screenless families (Direwolf / Vader) draw
/// a clean schematic without the central LCD cut-out.
struct Apex4Wireframe: View {
    var hasScreen: Bool = true
    var family: DeviceDescriptor.Family = .apex4
    var body: some View {
        if hasScreen, let img = Apex4Render.wireframe {
            Image(nsImage: img).resizable().interpolation(.high).aspectRatio(Apex4Render.canvas, contentMode: .fit)
        } else {
            ScreenlessGamepadWireframe(family: family).aspectRatio(Apex4Render.canvas, contentMode: .fit)
        }
    }
}

/// Crisp vector gamepad outline on the shared 508 × 421 stage canvas for screenless families (Direwolf / Vader).
struct ScreenlessGamepadWireframe: View {
    let family: DeviceDescriptor.Family
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width / 508, g.size.height / 421)
            Canvas { ctx, _ in
                ctx.scaleBy(x: s, y: s)
                let strokeColor = Color(hex: 0x777777)

                // Outer controller shell (508 × 421 coordinate space)
                var body = Path()
                body.move(to: CGPoint(x: 186, y: 298))
                body.addCurve(to: CGPoint(x: 89, y: 383), control1: CGPoint(x: 148, y: 298), control2: CGPoint(x: 112, y: 380))
                body.addCurve(to: CGPoint(x: 34, y: 314), control1: CGPoint(x: 68, y: 385), control2: CGPoint(x: 35, y: 374))
                body.addCurve(to: CGPoint(x: 85, y: 124), control1: CGPoint(x: 36, y: 230), control2: CGPoint(x: 75, y: 140))
                body.addCurve(to: CGPoint(x: 168, y: 74), control1: CGPoint(x: 102, y: 98), control2: CGPoint(x: 138, y: 76))
                body.addCurve(to: CGPoint(x: 195, y: 83), control1: CGPoint(x: 179, y: 74), control2: CGPoint(x: 188, y: 83))
                body.addLine(to: CGPoint(x: 313, y: 83))
                body.addCurve(to: CGPoint(x: 340, y: 74), control1: CGPoint(x: 320, y: 83), control2: CGPoint(x: 329, y: 74))
                body.addCurve(to: CGPoint(x: 422, y: 124), control1: CGPoint(x: 370, y: 76), control2: CGPoint(x: 405, y: 98))
                body.addCurve(to: CGPoint(x: 473, y: 314), control1: CGPoint(x: 432, y: 140), control2: CGPoint(x: 472, y: 230))
                body.addCurve(to: CGPoint(x: 419, y: 383), control1: CGPoint(x: 472, y: 374), control2: CGPoint(x: 440, y: 385))
                body.addCurve(to: CGPoint(x: 322, y: 298), control1: CGPoint(x: 395, y: 380), control2: CGPoint(x: 359, y: 298))
                body.closeSubpath()
                ctx.fill(body, with: .color(Color(hex: 0x1E1F22).opacity(0.65)))
                ctx.stroke(body, with: .color(strokeColor), lineWidth: 1.2)

                // Inner upper faceplate V-trim
                var vTrim = Path()
                vTrim.move(to: CGPoint(x: 158, y: 88))
                vTrim.addLine(to: CGPoint(x: 224, y: 176))
                vTrim.addQuadCurve(to: CGPoint(x: 284, y: 176), control: CGPoint(x: 254, y: 184))
                vTrim.addLine(to: CGPoint(x: 350, y: 88))
                ctx.stroke(vTrim, with: .color(strokeColor.opacity(0.65)), lineWidth: 1.0)

                // Center logo emblem (V-crest without any LCD screen rect)
                var crest = Path()
                crest.move(to: CGPoint(x: 235, y: 96))
                crest.addLine(to: CGPoint(x: 254, y: 112))
                crest.addLine(to: CGPoint(x: 273, y: 96))
                crest.addLine(to: CGPoint(x: 254, y: 132))
                crest.closeSubpath()
                ctx.stroke(crest, with: .color(Color(hex: 0xA8A8A8)), lineWidth: 1.4)

                // D-pad cross housing
                var dpad = Path()
                let cx: CGFloat = 198, cy: CGFloat = 234, arm: CGFloat = 13, span: CGFloat = 39
                dpad.move(to: CGPoint(x: cx - arm, y: cy - span))
                dpad.addLine(to: CGPoint(x: cx + arm, y: cy - span))
                dpad.addLine(to: CGPoint(x: cx + arm, y: cy - arm))
                dpad.addLine(to: CGPoint(x: cx + span, y: cy - arm))
                dpad.addLine(to: CGPoint(x: cx + span, y: cy + arm))
                dpad.addLine(to: CGPoint(x: cx + arm, y: cy + arm))
                dpad.addLine(to: CGPoint(x: cx + arm, y: cy + span))
                dpad.addLine(to: CGPoint(x: cx - arm, y: cy + span))
                dpad.addLine(to: CGPoint(x: cx - arm, y: cy + arm))
                dpad.addLine(to: CGPoint(x: cx - span, y: cy + arm))
                dpad.addLine(to: CGPoint(x: cx - span, y: cy - arm))
                dpad.addLine(to: CGPoint(x: cx - arm, y: cy - arm))
                dpad.closeSubpath()
                ctx.stroke(dpad, with: .color(strokeColor.opacity(0.65)), lineWidth: 1.1)

                // Twin indicator LEDs above bottom Fn/Mode pills on Direwolf series
                if family == .direwolf4 || family == .direwolf3 {
                    let bar1 = Path(roundedRect: CGRect(x: 247, y: 245, width: 14, height: 3), cornerRadius: 1.5)
                    let bar2 = Path(roundedRect: CGRect(x: 247, y: 253, width: 14, height: 3), cornerRadius: 1.5)
                    ctx.fill(bar1, with: .color(.white.opacity(0.6)))
                    ctx.fill(bar2, with: .color(strokeColor.opacity(0.5)))
                }
            }
        }
    }
}

/// Fallback body drawing (shapes only) when the artwork is absent.
struct Apex4BodyShape: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Capsule().fill(.white.opacity(0.06)).frame(width: w * 0.22, height: h * 0.62).rotationEffect(.degrees(12)).offset(x: -w * 0.30, y: h * 0.16)
                Capsule().fill(.white.opacity(0.06)).frame(width: w * 0.22, height: h * 0.62).rotationEffect(.degrees(-12)).offset(x: w * 0.30, y: h * 0.16)
                RoundedRectangle(cornerRadius: w * 0.16).fill(.white.opacity(0.08)).frame(width: w * 0.78, height: h * 0.58).offset(y: -h * 0.02)
                RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.7)).frame(width: w * 0.16, height: h * 0.10).offset(y: -h * 0.24)
                Circle().fill(.white.opacity(0.10)).frame(width: w * 0.16).offset(x: -w * 0.26, y: -h * 0.10)
                Circle().fill(.white.opacity(0.10)).frame(width: w * 0.16).offset(x: w * 0.12, y: h * 0.18)
            }
            .frame(width: w, height: h)
        }
    }
}
