import AppKit

func generateIcon(outputPath: String) {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else { return }

    // 1. Drop shadow behind the squircle
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.shadowBlurRadius = 38
    shadow.set()

    // 2. Base Squircle Shape (Apple standard 824x824 at 100,100, radius 185)
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)

    NSColor.black.setFill()
    squirclePath.fill()

    // Clear shadow for interior drawing
    NSShadow().set()

    context.saveGState()
    squirclePath.addClip()

    // 3. Deep Modern Dark Gradient (Space Black to Slate)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.12, green: 0.13, blue: 0.18, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0).cgColor
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    context.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 512, y: 924),
        end: CGPoint(x: 512, y: 100),
        options: []
    )

    // 4. Ambient Radial Glow behind Text
    let glowColors = [
        NSColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 0.22).cgColor,
        NSColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 0.0).cgColor
    ] as CFArray
    let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: 512, y: 512),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 400,
        options: []
    )

    // 5. Automatic Safe Bound Calculation (Max width 620pt inside 824pt squircle)
    let maxSafeWidth: CGFloat = 620.0

    var satsetFontSize: CGFloat = 165.0
    while satsetFontSize > 80.0 {
        let testFont = NSFont.systemFont(ofSize: satsetFontSize, weight: .heavy)
        let testWidth = ("SATSET" as NSString).size(withAttributes: [.font: testFont]).width
        if testWidth <= maxSafeWidth {
            break
        }
        satsetFontSize -= 2.0
    }

    let miniFontSize: CGFloat = round(satsetFontSize * 0.58) // ~95pt

    let miniAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: miniFontSize, weight: .heavy),
        .foregroundColor: NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0), // Electric amber
        .kern: 2.0
    ]
    let miniText = NSAttributedString(string: "MINI", attributes: miniAttrs)

    let satsetAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: satsetFontSize, weight: .heavy),
        .foregroundColor: NSColor.white,
        .kern: -1.0
    ]
    let satsetText = NSAttributedString(string: "SATSET", attributes: satsetAttrs)

    let miniSize = miniText.size()
    let satsetSize = satsetText.size()

    // Tight padding between lines
    let gapBetweenLines: CGFloat = 4.0

    let totalHeight = miniSize.height + gapBetweenLines + satsetSize.height
    let blockBottomY = round((1024.0 - totalHeight) / 2.0)

    // Absolute Horizontal & Vertical Center Positioning
    let satsetPoint = NSPoint(
        x: round((1024.0 - satsetSize.width) / 2.0),
        y: blockBottomY
    )

    let miniPoint = NSPoint(
        x: round((1024.0 - miniSize.width) / 2.0),
        y: satsetPoint.y + satsetSize.height + gapBetweenLines
    )

    // Draw using exact point-based rendering
    satsetText.draw(at: satsetPoint)
    miniText.draw(at: miniPoint)

    // 6. Subtle Inner Squircle Border
    context.restoreGState()
    squirclePath.lineWidth = 2.0
    NSColor(white: 1.0, alpha: 0.14).setStroke()
    squirclePath.stroke()

    image.unlockFocus()

    // Write PNG
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Gagal generate PNG")
        return
    }

    try? pngData.write(to: URL(fileURLWithPath: outputPath))
    print("PNG generated: \(outputPath)")
    print("SATSET font size: \(satsetFontSize)pt, width: \(satsetSize.width)pt (Safe limit: \(maxSafeWidth)pt)")
    print("MINI font size: \(miniFontSize)pt, width: \(miniSize.width)pt")
}

let args = CommandLine.arguments
if args.count > 1 {
    generateIcon(outputPath: args[1])
} else {
    generateIcon(outputPath: "Resources/icon_1024.png")
}
