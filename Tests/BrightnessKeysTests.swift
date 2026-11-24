import XCTest
import Carbon

final class BrightnessKeysTests: XCTestCase {
    func testKeyboardStepsIncreaseAndDecreaseByOneSixteenth() {
        XCTAssertEqual(BrightnessStep.nextLevel(0.5, direction: 1, software: false), 0.5625)
        XCTAssertEqual(BrightnessStep.nextLevel(0.5, direction: -1, software: false), 0.4375)
    }

    func testHardwareAndSoftwareLevelsStayWithinSafeBounds() {
        XCTAssertEqual(BrightnessStep.nextLevel(0.99, direction: 1, software: false), 1)
        XCTAssertEqual(BrightnessStep.nextLevel(0.01, direction: -1, software: false), 0)
        XCTAssertEqual(BrightnessStep.nextLevel(0.21, direction: -1, software: true), 0.2)
    }

    func testInvalidLevelsAndDirectionsDoNotProduceDisplayWrites() {
        for level in [Double.nan, .infinity, -1, 2] {
            XCTAssertNil(BrightnessStep.nextLevel(level, direction: 1, software: false))
        }
        for direction in [0, 2, Int.min] {
            XCTAssertNil(BrightnessStep.nextLevel(0.5, direction: direction, software: false))
        }
    }

    func testHotKeyEventsAreRoutedToTheirOwnFeatureOnly() {
        var event: EventRef?
        XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event), noErr)
        guard let event else { return XCTFail("Unable to construct registered shortcut event") }
        defer { ReleaseEvent(event) }
        var id = EventHotKeyID(signature: 0x4D504C42, id: 1)
        XCTAssertEqual(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        MemoryLayout<EventHotKeyID>.size, &id), noErr)
        XCTAssertEqual(registeredHotKeyID(event, signature: 0x4D504C42), 1)
        XCTAssertNil(registeredHotKeyID(event, signature: 0x4D43504C))
        XCTAssertNil(registeredHotKeyID(nil, signature: 0x4D504C42))
    }
}
