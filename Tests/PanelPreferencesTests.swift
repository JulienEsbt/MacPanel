import XCTest

@MainActor
final class PanelPreferencesTests: XCTestCase {
    func testOrderVisibilityAndCommandsSurviveRelaunchAndIgnoreUnknownIDs() throws {
        let name = "MacPanel.PreferencesTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["unknown", "commands", "commands"], forKey: "panelSections")
        let prefs = PanelPreferences(defaults: defaults)
        XCTAssertEqual(prefs.sections.first, .commands)
        XCTAssertEqual(Set(prefs.sections).count, PanelSection.allCases.count)
        prefs.setVisible(.telemetry, false)
        prefs.move(.apps, by: -1)
        prefs.setCommandVisible(.muted, false)
        let restored = PanelPreferences(defaults: defaults)
        XCTAssertFalse(restored.isVisible(.telemetry))
        XCTAssertFalse(restored.visibleCommands.contains(.muted))
        XCTAssertEqual(restored.sections, prefs.sections)
        restored.reset()
        XCTAssertEqual(restored.sections, PanelSection.allCases)
        XCTAssertEqual(restored.visibleCommands, QuickSwitch.allCases)
    }
}
