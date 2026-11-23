import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let length = CGFloat(pixels)
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: NSRect(x: length * 0.06, y: length * 0.06,
            width: length * 0.88, height: length * 0.88), xRadius: length * 0.20, yRadius: length * 0.20).fill()
        let symbol = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white]))!
        symbol.draw(in: NSRect(x: length * 0.22, y: length * 0.27,
                              width: length * 0.56, height: length * 0.46))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
