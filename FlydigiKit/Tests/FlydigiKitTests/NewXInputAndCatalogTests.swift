import Testing
import Foundation
@testable import FlydigiKit

@Suite struct DeviceCatalogAndCapabilities {
    @Test func direwolf4IsMappedAsDirewolfFamily() throws {
        let d = try #require(DeviceCatalog.descriptor(for: 132))
        #expect(d.family == .direwolf4)
        #expect(d.protocolVariant == .newXInput)
        #expect(d.capabilities.ledGroups == 0)
        #expect(d.capabilities.screen == nil)
        #expect(d.capabilities.forceAdaptTriggers == false)
        #expect(d.capabilities.backPaddles == 2)
        #expect(d.capabilities.hasCZButtons == false)
        #expect(d.capabilities.supportsReportRate == true)
    }

    @Test func vader4ProCapabilities() throws {
        let d = try #require(DeviceCatalog.descriptor(for: 85))
        #expect(d.family == .vader4pro)
        #expect(d.protocolVariant == .classic)
        #expect(d.capabilities.screen == nil)
        #expect(d.capabilities.ledGroups == 1)
        #expect(d.capabilities.forceAdaptTriggers == false)
        #expect(d.capabilities.triggerVibration == true)
        #expect(d.capabilities.backPaddles == 4)
        #expect(d.capabilities.hasCZButtons == true)
        #expect(d.capabilities.supportsReportRate == true)
    }

    @Test func apex4Capabilities() throws {
        let d = try #require(DeviceCatalog.descriptor(for: 84))
        #expect(d.family == .apex4)
        #expect(d.capabilities.screen != nil)
        #expect(d.capabilities.forceAdaptTriggers == true)
        #expect(d.capabilities.backPaddles == 4)
        #expect(d.capabilities.hasCZButtons == false)
        #expect(d.capabilities.supportsReportRate == false)
    }

    @Test func reportRateWireValues() {
        #expect(ReportRate(rawValue: 1)?.hz == 1000)
        #expect(ReportRate(rawValue: 2)?.hz == 500)
        #expect(ReportRate(rawValue: 4)?.hz == 250)
        #expect(ReportRate(rawValue: 8)?.hz == 125)
    }
}

@Suite struct NewXInputProtocol {
    @Test func heartbeatFraming() {
        let plain = NewXInput.heartbeat()
        #expect(plain.count == 32)
        #expect(plain[0] == 0x5A && plain[1] == 0xA5 && plain[2] == 0x01 && plain[3] == 0x02)
        #expect(plain[31] == 0x03)

        let prefixed = NewXInput.heartbeat(reportId: 0x03)
        #expect(prefixed.count == 33)
        #expect(prefixed[0] == 0x03 && prefixed[1] == 0x5A && prefixed[2] == 0xA5)
    }

    @Test func parsesUnprefixedAndPrefixedDeviceInfo() throws {
        // 5A A5 01 00 00 <dev=0x84> <conn=0x00 wired> <mac 4B> <batt=0x25> 00 00 00 <fwHigh=0x72> <fwLow=0x40>
        var raw = [UInt8](repeating: 0, count: 32)
        raw[0] = 0x5A; raw[1] = 0xA5; raw[2] = 0x01
        raw[5] = 0x84          // Direwolf 4 (132)
        raw[6] = 0x00          // wired
        raw[7] = 0xAA; raw[8] = 0xBB; raw[9] = 0xCC; raw[10] = 0xDD
        raw[11] = 0x25         // full/charging high nibble 2, 5 bars
        raw[15] = 0x72; raw[16] = 0x40   // 7.2.4.0

        let info = try #require(NewXInputReply.deviceInfo(raw))
        #expect(info.deviceId == 132)
        #expect(info.isWired)
        #expect(info.firmware == "7.2.4.0")
        #expect(info.batteryRaw == 0x15)
        #expect(info.mac == [0xAA, 0xBB, 0xCC, 0xDD])

        // Report-ID prefixed variant (wireless conn = 1)
        raw[6] = 0x01
        raw[11] = 0x04
        let prefixedInfo = try #require(NewXInputReply.deviceInfo([0x03] + raw))
        #expect(prefixedInfo.deviceId == 132)
        #expect(!prefixedInfo.isWired)
        #expect(prefixedInfo.batteryRaw == 0x04)
    }
}
