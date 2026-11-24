import XCTest
import Carbon

final class ShortcutTests: XCTestCase {
    @MainActor
    func testLetterMCanBeLocatedInTheCurrentKeyboardLayout() async throws {
        let key = try XCTUnwrap(PanelShortcut.keyCodeForM())
        XCTAssertLessThan(key, 128)
        print("MacPanel shortcut: M maps to key code \(key)")
    }

    @MainActor
    func testPanelHandlerRejectsBrightnessCommandsAndAcceptsItsOwnCommand() async throws {
        let shortcut = PanelShortcut()
        var calls = 0
        shortcut.start { calls += 1 }
        defer { shortcut.stop() }
        XCTAssertNil(shortcut.error)
        var event: EventRef?
        XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event), noErr)
        let message = try XCTUnwrap(event)
        defer { ReleaseEvent(message) }
        var id = EventHotKeyID(signature: 0x4D504C42, id: 1)
        XCTAssertEqual(SetEventParameter(message, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        MemoryLayout<EventHotKeyID>.size, &id), noErr)
        _ = SendEventToEventTarget(message, GetApplicationEventTarget())
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(calls, 0)
        id.signature = 0x4D43504C
        XCTAssertEqual(SetEventParameter(message, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        MemoryLayout<EventHotKeyID>.size, &id), noErr)
        XCTAssertEqual(SendEventToEventTarget(message, GetApplicationEventTarget()), noErr)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(calls, 1)
    }
}
