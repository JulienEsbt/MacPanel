import XCTest

final class ShortcutTests: XCTestCase {
    @MainActor
    func testLetterMCanBeLocatedInTheCurrentKeyboardLayout() async throws {
        let key = try XCTUnwrap(PanelShortcut.keyCodeForM())
        XCTAssertLessThan(key, 128)
        print("MacPanel shortcut: M maps to key code \(key)")
    }
}
