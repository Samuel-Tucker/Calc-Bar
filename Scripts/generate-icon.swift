import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: cornerRadius, yRadius: cornerRadius)

    NSColor(calibratedRed: 0.80, green: 0.88, blue: 0.88, alpha: 1).setFill()
    background.fill()

    NSColor(calibratedWhite: 0.08, alpha: 0.95).setFill()
    let display = NSBezierPath(
        roundedRect: NSRect(x: size * 0.20, y: size * 0.56, width: size * 0.60, height: size * 0.22),
        xRadius: size * 0.06,
        yRadius: size * 0.06
    )
    display.fill()

    NSColor(calibratedRed: 0.20, green: 0.61, blue: 0.48, alpha: 1).setFill()
    let equals = NSBezierPath(
        roundedRect: NSRect(x: size * 0.60, y: size * 0.18, width: size * 0.20, height: size * 0.20),
        xRadius: size * 0.05,
        yRadius: size * 0.05
    )
    equals.fill()

    NSColor(calibratedWhite: 0.24, alpha: 1).setFill()
    for row in 0..<2 {
        for column in 0..<3 {
            let key = NSBezierPath(
                roundedRect: NSRect(
                    x: size * (0.20 + CGFloat(column) * 0.20),
                    y: size * (0.18 + CGFloat(row) * 0.20),
                    width: size * 0.14,
                    height: size * 0.14
                ),
                xRadius: size * 0.035,
                yRadius: size * 0.035
            )
            key.fill()
        }
    }

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let plusAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.18, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    "+".draw(in: NSRect(x: size * 0.20, y: size * 0.585, width: size * 0.60, height: size * 0.18), withAttributes: plusAttributes)

    let equalsAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.15, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    "=".draw(in: NSRect(x: size * 0.60, y: size * 0.205, width: size * 0.20, height: size * 0.13), withAttributes: equalsAttributes)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to render \(name)")
    }

    try png.write(to: iconset.appendingPathComponent(name))
}
