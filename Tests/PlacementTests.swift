import XCTest

final class PlacementTests: XCTestCase {
    func testPanelRemainsInsideExternalScreenWithNegativeOrigin() {
        let screen = CGRect(x: -1920, y: -1080, width: 1920, height: 1056)
        let size = CGSize(width: 392, height: 650)
        let anchor = CGRect(x: -32, y: -24, width: 24, height: 24)
        let frame = CGRect(origin: PanelPlacement.origin(size: size, anchor: anchor, visible: screen), size: size)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertLessThanOrEqual(frame.maxY, anchor.minY)
    }

    func testPanelNeverUsesAnotherScreenOrCrossesMenuBar() {
        for screen in [CGRect(x: 0, y: 0, width: 1920, height: 1056),
                       CGRect(x: 1920, y: 1080, width: 1710, height: 1044)] {
            for x in [screen.minX, screen.maxX - 24] {
                let size = CGSize(width: 392, height: 650)
                let anchor = CGRect(x: x, y: screen.maxY, width: 24, height: 24)
                let frame = CGRect(origin: PanelPlacement.origin(size: size, anchor: anchor, visible: screen), size: size)
                XCTAssertTrue(screen.contains(frame))
            }
        }
    }
}
