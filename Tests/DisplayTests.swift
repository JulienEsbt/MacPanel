import XCTest
import AppKit

final class DisplayTests: XCTestCase {
    func testFixedOffsetUsesWholePointsAndRejectsInvalidInput() {
        XCTAssertEqual(BrightnessSync.fixedOffset(0.09999999999999998), 0.1)
        XCTAssertEqual(BrightnessSync.fixedOffset(-0.20999999999999996), -0.21)
        XCTAssertEqual(BrightnessSync.fixedOffset(1), 0.5)
        XCTAssertEqual(BrightnessSync.fixedOffset(-1), -0.5)
        XCTAssertNil(BrightnessSync.fixedOffset(.nan))
        XCTAssertNil(BrightnessSync.fixedOffset(.infinity))
    }

    func testLinkedSliderUsesTheExternalOffsetWithoutChangingIt() throws {
        XCTAssertEqual(try XCTUnwrap(BrightnessSync.sourceLevel(changedLevel: 0.7, offset: 0.1, isBuiltin: false)), 0.6, accuracy: 0.0001)
        XCTAssertEqual(BrightnessSync.sourceLevel(changedLevel: 0.7, offset: 0.1, isBuiltin: true), 0.7)
        XCTAssertEqual(BrightnessSync.sourceLevel(changedLevel: 0.05, offset: 0.1, isBuiltin: false), 0)
        XCTAssertNil(BrightnessSync.sourceLevel(changedLevel: .nan, offset: 0, isBuiltin: false))
        XCTAssertEqual(BrightnessSync.range(offset: 0.1, software: false, linked: true), 0.1...1)
        XCTAssertEqual(BrightnessSync.range(offset: -0.1, software: false, linked: true), 0...0.9)
        XCTAssertEqual(BrightnessSync.range(offset: 0.1, software: true, linked: false), 0.2...1)
    }

    func testSynchronizationBoundsAndOffsetsAreSafe() {
        XCTAssertEqual(BrightnessSync.level(source: 0.6, offset: -0.1, software: false)!, 0.5, accuracy: 0.0001)
        XCTAssertEqual(BrightnessSync.level(source: 0.9, offset: 0.5, software: false), 1)
        XCTAssertEqual(BrightnessSync.level(source: 0.1, offset: -0.5, software: true), 0.2)
        XCTAssertNil(BrightnessSync.level(source: .nan, offset: 0, software: false))
        XCTAssertNil(BrightnessSync.level(source: 0.5, offset: .infinity, software: false))
    }

    func testVolumeRepliesCannotBeConfusedWithBrightnessOrUnsupportedVCP() {
        var reply: [UInt8] = [0x6E, 0x88, 2, 0, 0x62, 0, 0, 100, 0, 35, 0]
        reply[10] = reply.prefix(10).reduce(0x50, ^)
        var current: UInt16 = 0, maximum: UInt16 = 0
        XCTAssertTrue(MPDecodeVCPReply(reply, reply.count, 0x62, &current, &maximum))
        XCTAssertEqual(current, 35)
        XCTAssertFalse(MPDecodeVCPReply(reply, reply.count, 0x10, &current, &maximum))
        XCTAssertFalse(MPDecodeVCPReply(reply, reply.count, 0xD6, &current, &maximum))
        for value in [-1, 2, .nan, .infinity] { XCTAssertFalse(MPWriteDisplayVolume(0, value)) }
    }

    func testMalformedGammaTablesAreRejectedBeforeCallingTheDisplayAPI() {
        XCTAssertFalse(GammaTable(red: [0, 1], green: [0], blue: [0, 1]).apply(0))
        XCTAssertFalse(GammaTable(red: [], green: [], blue: []).apply(0))
        XCTAssertFalse(GammaTable(red: [.nan], green: [0], blue: [0]).apply(0))
    }
    func testSoftwareDimmingScalesOriginalTablesWithoutChangingTheirShape() {
        let original = GammaTable(red: [0, 0.4, 1], green: [0, 0.5, 1], blue: [0, 0.6, 1])
        let dimmed = original.scaled(0.5)
        XCTAssertEqual(dimmed.red, [0, 0.2, 0.5])
        XCTAssertEqual(original.red, [0, 0.4, 1])
        XCTAssertTrue(original.matches(original.scaled(1)))
        XCTAssertFalse(original.matches(dimmed))
        XCTAssertFalse(original.matches(GammaTable(red: [0, .nan, 1], green: [0, 0.5, 1], blue: [0, 0.6, 1])))
        XCTAssertFalse(original.matches(GammaTable(red: [0, 1], green: [0, 1], blue: [0, 1])))
    }

    @MainActor
    func testActualScreensExposeOnlyValidBrightnessOrUnsupported() async {
        let reader = BrightnessReader()
        let screens = NSScreen.screens.map { screen in
            (screen.localizedName, (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value)
        }
        for (name, id) in screens {
            guard let id else { continue }
            let (brightness, mode) = await reader.read(id)
            let volume = await reader.readVolume(id)
            print("MacPanel display: \(name), backend=\(mode), brightness=\(String(describing: brightness)), speakerVolume=\(String(describing: volume))")
            if let brightness { XCTAssertTrue((0...1).contains(brightness)); XCTAssertTrue([1, 2].contains(mode)) }
            else { XCTAssertEqual(mode, 0) }
        }
    }

    func testDDCReplyIsValidatedBeforeUsingItsValue() {
        var reply: [UInt8] = [0x6E, 0x88, 2, 0, 0x10, 0, 0, 100, 0, 42, 0, 0]
        reply[10] = reply.prefix(10).reduce(0x50, ^)
        var current: UInt16 = 0, maximum: UInt16 = 0
        XCTAssertTrue(MPDecodeBrightnessReply(reply, reply.count, &current, &maximum))
        XCTAssertEqual(current, 42)
        XCTAssertEqual(maximum, 100)
        reply[10] ^= 1
        XCTAssertFalse(MPDecodeBrightnessReply(reply, reply.count, &current, &maximum))
        XCTAssertFalse(MPDecodeBrightnessReply(reply, 5, &current, &maximum))
        XCTAssertFalse(MPDecodeBrightnessReply(nil, 12, &current, &maximum))
    }

    func testDDCUnsupportedOrImpossibleValuesAreRejected() {
        for (result, current, maximum): (UInt8, UInt8, UInt8) in [(1, 42, 100), (0, 42, 0), (0, 101, 100)] {
            var reply: [UInt8] = [0x6E, 0x88, 2, result, 0x10, 0, 0, maximum, 0, current, 0]
            reply[10] = reply.prefix(10).reduce(0x50, ^)
            var value: UInt16 = 0, max: UInt16 = 0
            XCTAssertFalse(MPDecodeBrightnessReply(reply, reply.count, &value, &max))
        }
    }

    func testDisplayWritesRejectInvalidInputWithoutHardwareChanges() {
        for value in [-1, 2, .nan, .infinity] { XCTAssertFalse(MPWriteBrightness(0, value)) }
    }
}

private actor BrightnessFixture {
    var value = 0.4
    var reads = 0
    func read() -> (Double?, Int32) { reads += 1; return (value, 1) }
    func change(to value: Double) { self.value = value }
    func count() -> Int { reads }
}

extension DisplayTests {
    @MainActor
    func testVisiblePanelFollowsNativeBrightnessChangesAndStopsReadingWhenClosed() async throws {
        let fixture = BrightnessFixture()
        let reader = BrightnessReader(readOverride: { _ in await fixture.read() })
        let controller = DisplayController(reader: reader)
        controller.refresh()
        for _ in 0..<100 {
            if !controller.displays.isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(controller.displays.isEmpty)
        controller.startObserving()
        await fixture.change(to: 0.65)
        for _ in 0..<100 {
            if controller.displays.first?.brightness == 0.65 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(controller.displays.first?.brightness, 0.65)
        controller.stopObserving()
        let reads = await fixture.count()
        await fixture.change(to: 0.8)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(controller.displays.first?.brightness, 0.65)
        let finalReads = await fixture.count()
        XCTAssertEqual(finalReads, reads)
    }
}
