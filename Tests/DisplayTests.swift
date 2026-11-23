import XCTest
import AppKit

final class DisplayTests: XCTestCase {
    func testSoftwareDimmingScalesOriginalTablesWithoutChangingTheirShape() {
        let original = GammaTable(red: [0, 0.4, 1], green: [0, 0.5, 1], blue: [0, 0.6, 1])
        let dimmed = original.scaled(0.5)
        XCTAssertEqual(dimmed.red, [0, 0.2, 0.5])
        XCTAssertEqual(original.red, [0, 0.4, 1])
        XCTAssertTrue(original.matches(original.scaled(1)))
        XCTAssertFalse(original.matches(dimmed))
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
            print("MacPanel display: \(name), backend=\(mode), brightness=\(String(describing: brightness))")
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
