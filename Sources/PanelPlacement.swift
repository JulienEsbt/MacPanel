import Foundation

enum PanelPlacement {
    static func origin(size: CGSize, anchor: CGRect, visible: CGRect) -> CGPoint {
        let x = anchor.midX - size.width / 2
        let y = anchor.minY - size.height - 4
        return CGPoint(x: min(max(x, visible.minX), max(visible.minX, visible.maxX - size.width)),
                       y: min(max(y, visible.minY), max(visible.minY, visible.maxY - size.height)))
    }
}
