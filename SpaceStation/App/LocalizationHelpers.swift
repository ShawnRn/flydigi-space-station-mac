// Localized model names and key descriptions for App UI views.

import Foundation
import FlydigiKit

extension DeviceDescriptor {
    var localizedName: String {
        switch id {
        case 84: return String(localized: "Flydigi Apex 4")
        case 86: return String(localized: "Flydigi Apex 4 EVA")
        case 87: return String(localized: "Flydigi Apex 4 STN")
        case 92: return String(localized: "Flydigi Apex 4 Assassin's Creed")
        case 85: return String(localized: "Flydigi Vader 4 Pro")
        case 91: return String(localized: "Flydigi Vader 4 Pro Assassin's Creed")
        case 105: return String(localized: "Flydigi Vader 4 Pro (105)")
        case 28: return String(localized: "Flydigi Vader 3")
        case 80: return String(localized: "Flydigi Vader 3 Pro")
        case 130: return String(localized: "Flydigi Vader 5 Pro")
        case 132: return String(localized: "Flydigi Direwolf 4")
        case 146: return String(localized: "Flydigi Direwolf 4 Yoimiya")
        case 147: return String(localized: "Flydigi Direwolf 4 Custom")
        case 148: return String(localized: "Flydigi Direwolf 4 Endfield")
        case 151: return String(localized: "Flydigi Direwolf 4 Phantom Blade")
        case 95: return String(localized: "Flydigi Direwolf 3")
        case 97: return String(localized: "Flydigi Direwolf 3 Naruto")
        case 128: return String(localized: "Flydigi Apex 5")
        case 24: return String(localized: "Flydigi Apex 3")
        default: return name
        }
    }
}

extension ControllerKey {
    func localizedName(switchMode: Bool) -> String {
        if switchMode {
            switch self {
            case .lt: return "ZL"
            case .rt: return "ZR"
            case .lb: return "L"
            case .rb: return "R"
            case .select: return String(localized: "Minus (−)")
            case .start: return String(localized: "Plus (+)")
            case .back: return String(localized: "Capture (Screenshot)")
            case .home: return String(localized: "Home (NS)")
            case .c: return String(localized: "C button")
            default: break
            }
        }
        return localizedName
    }

    var localizedName: String {
        switch self {
        case .up: return String(localized: "D-pad Up")
        case .right: return String(localized: "D-pad Right")
        case .down: return String(localized: "D-pad Down")
        case .left: return String(localized: "D-pad Left")
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .select: return "Select"
        case .start: return "Start"
        case .lb: return "LB"
        case .rb: return "RB"
        case .lt: return "LT"
        case .rt: return "RT"
        case .thumbL: return String(localized: "L-stick click")
        case .thumbR: return String(localized: "R-stick click")
        case .c: return "C"
        case .z: return "Z"
        case .m1: return "M1"
        case .m2: return "M2"
        case .m3: return "M3"
        case .m4: return "M4"
        case .m5: return "M5"
        case .m6: return "M6"
        case .menu: return "Fn"
        case .turbo: return "Turbo"
        case .home: return "Home"
        case .back: return String(localized: "Back")
        case .macro: return String(localized: "Macro")
        case .jsLeft: return String(localized: "Left stick")
        case .jsRight: return String(localized: "Right stick")
        case .jsWheel: return String(localized: "Wheel")
        case .keyboardMouse: return String(localized: "Keyboard/Mouse")
        case .none: return "—"
        default: return description
        }
    }
}
