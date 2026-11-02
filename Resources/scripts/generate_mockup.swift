import AppKit

func generateMockup(outputPath: String) {
    let width: CGFloat = 3400
    let height: CGFloat = 1350
    let size = NSSize(width: width, height: height)
    let image = NSImage(size: size)

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 1. Desktop Wallpaper Backdrop (Deep Midnight Blue to Cosmic Obsidian)
    let bgColors = [
        NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0).cgColor,
        NSColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.5, 1.0])!
    context.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

    // 2. Cosmic Ambient Light Glows
    let blueGlowColors = [
        NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.22).cgColor,
        NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let blueGlow = CGGradient(colorsSpace: colorSpace, colors: blueGlowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(blueGlow, startCenter: CGPoint(x: 1700, y: 650), startRadius: 0, endCenter: CGPoint(x: 1700, y: 650), endRadius: 900, options: [])

    let amberGlowColors = [
        NSColor(red: 1.0, green: 0.62, blue: 0.1, alpha: 0.16).cgColor,
        NSColor(red: 1.0, green: 0.62, blue: 0.1, alpha: 0.0).cgColor
    ] as CFArray
    let amberGlow = CGGradient(colorsSpace: colorSpace, colors: amberGlowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(amberGlow, startCenter: CGPoint(x: 700, y: 400), startRadius: 0, endCenter: CGPoint(x: 700, y: 400), endRadius: 600, options: [])

    // 3. Header Showcase Branding
    let centerParagraph = NSMutableParagraphStyle()
    centerParagraph.alignment = .center

    let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0),
        .paragraphStyle: centerParagraph,
        .kern: 4.0
    ]
    let subtitle = NSAttributedString(string: "MACOS MENU BAR UTILITY", attributes: subtitleAttrs)
    subtitle.draw(in: NSRect(x: 0, y: height - 120, width: width, height: 32))

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 52, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: centerParagraph,
        .kern: -1.0
    ]
    let title = NSAttributedString(string: "mini-satset • All 5 Native Pages + Pin Mode", attributes: titleAttrs)
    title.draw(in: NSRect(x: 0, y: height - 190, width: width, height: 65))

    let descAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 21, weight: .medium),
        .foregroundColor: NSColor(white: 0.72, alpha: 1.0),
        .paragraphStyle: centerParagraph
    ]
    let desc = NSAttributedString(string: "Shelf  •  Quick Converter  •  Color Sampler  •  QR Code Lab  •  Screen OCR Grabber", attributes: descAttrs)
    desc.draw(in: NSRect(x: 0, y: height - 235, width: width, height: 35))

    // 4. Draw the 5 Symmetrical Panels
    let panelW: CGFloat = 580
    let panelH: CGFloat = 664
    let spacing: CGFloat = 35
    let totalPanelsW = 5 * panelW + 4 * spacing
    let startX = (width - totalPanelsW) / 2
    let panelY: CGFloat = 170

    for i in 0..<5 {
        drawPanelMockup(context: context, x: startX + CGFloat(i) * (panelW + spacing), y: panelY, width: panelW, height: panelH, pageIndex: i)
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Gagal generate mockup PNG")
        return
    }

    try? pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Mockup generated successfully at: \(outputPath)")
}

func drawPanelMockup(context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, pageIndex: Int) {
    let panelRect = NSRect(x: x, y: y, width: width, height: height)
    let cornerRadius: CGFloat = 32

    // Drop shadow
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowOffset = NSSize(width: 0, height: -30)
    shadow.shadowBlurRadius = 45
    shadow.set()

    let path = NSBezierPath(roundedRect: panelRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 0.96).setFill()
    path.fill()

    NSShadow().set()

    // Inner subtle border
    path.lineWidth = 2.0
    NSColor(white: 1.0, alpha: 0.14).setStroke()
    path.stroke()

    // Navbar Top (height 76 @2x)
    let navY = y + height - 76
    let navSep = NSBezierPath()
    navSep.move(to: NSPoint(x: x, y: navY))
    navSep.line(to: NSPoint(x: x + width, y: navY))
    navSep.lineWidth = 1.0
    NSColor(white: 1.0, alpha: 0.08).setStroke()
    navSep.stroke()

    // Navbar tabs (5 pages)
    let symbols = ["doc.on.clipboard", "arrow.2.squarepath", "eyedropper.halffull", "qrcode", "text.viewfinder"]
    let tabW: CGFloat = 62
    let tabH: CGFloat = 50
    let tabSpacing: CGFloat = 10
    let totalTabsW = CGFloat(symbols.count) * tabW + CGFloat(symbols.count - 1) * tabSpacing
    let tabStartX = x + (width - totalTabsW) / 2
    let tabY = navY + (76 - tabH) / 2

    for (i, sym) in symbols.enumerated() {
        let currentTabX = tabStartX + CGFloat(i) * (tabW + tabSpacing)
        let tabRect = NSRect(x: currentTabX, y: tabY, width: tabW, height: tabH)

        if i == pageIndex {
            let activePill = NSBezierPath(roundedRect: tabRect, xRadius: 10, yRadius: 10)
            NSColor(white: 1.0, alpha: 0.12).setFill()
            activePill.fill()
        }

        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        if let icon = NSImage(systemSymbolName: sym, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let iconW: CGFloat = 24
            let iconH: CGFloat = 24
            let iconRect = NSRect(x: currentTabX + (tabW - iconW) / 2, y: tabY + (tabH - iconH) / 2, width: iconW, height: iconH)
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: (i == pageIndex) ? 1.0 : 0.45)
        }
    }

    // Pin Button (Top right header)
    let pinRect = NSRect(x: x + width - 56, y: tabY + 4, width: 42, height: 42)
    let pinPath = NSBezierPath(roundedRect: pinRect, xRadius: 8, yRadius: 8)
    NSColor(white: 1.0, alpha: 0.06).setFill()
    pinPath.fill()
    let pinConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
    if let pinIcon = NSImage(systemSymbolName: "pin", accessibilityDescription: nil)?.withSymbolConfiguration(pinConfig) {
        let pinIconRect = NSRect(x: pinRect.minX + 11, y: pinRect.minY + 11, width: 20, height: 20)
        pinIcon.draw(in: pinIconRect, from: .zero, operation: .sourceOver, fraction: 0.55)
    }

    // Page Content Rendering (@2x scaling: margin 24, cardWidth 532)
    let contentX = x + 24
    let contentW: CGFloat = width - 48

    if pageIndex == 0 {
        // === PAGE 1: SHELF ===
        // 1. Files grid container (y = y + 390, h = 168)
        let fileDropRect = NSRect(x: contentX, y: y + 390, width: contentW, height: 168)
        let fileDropPath = NSBezierPath(roundedRect: fileDropRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.04).setFill()
        fileDropPath.fill()

        // 2 File cards inside
        let fW: CGFloat = (contentW - 36) / 2
        let f0Rect = NSRect(x: contentX + 12, y: y + 402, width: fW, height: 144)
        let f1Rect = NSRect(x: contentX + 24 + fW, y: y + 402, width: fW, height: 144)
        drawFileMiniCard(rect: f0Rect, name: "recording.wav", size: "WAV • 14.2 MB", iconName: "waveform")
        drawFileMiniCard(rect: f1Rect, name: "design.png", size: "PNG • 3.8 MB", iconName: "photo")

        // 2. Text Input row (y = y + 320, h = 52)
        let inputRect = NSRect(x: contentX, y: y + 320, width: contentW - 140, height: 52)
        let inputPath = NSBezierPath(roundedRect: inputRect, xRadius: 14, yRadius: 14)
        NSColor(white: 1.0, alpha: 0.06).setFill()
        inputPath.fill()
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        inputPath.stroke()

        let inputPlaceholder = NSAttributedString(string: "Type or paste text...", attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .regular),
            .foregroundColor: NSColor(white: 0.45, alpha: 1.0)
        ])
        inputPlaceholder.draw(at: NSPoint(x: contentX + 18, y: y + 333))

        // Paste & Add buttons
        drawMiniSquareButton(x: contentX + contentW - 128, y: y + 320, size: 52, icon: "doc.on.clipboard")
        drawMiniSquareButton(x: contentX + contentW - 60, y: y + 320, size: 52, icon: "plus")

        // 3. Text snippets cards (y = y + 74, h = 232)
        let snippets = [
            "https://apple.com/macos/sequoia",
            "git commit -m 'release: v1.1.0 mini-satset'",
            "SATSET-PROMO-2026-KEY"
        ]
        for (idx, snip) in snippets.enumerated() {
            let snipY = y + 250 - CGFloat(idx) * 60
            let snipRect = NSRect(x: contentX, y: snipY, width: contentW, height: 50)
            let snipPath = NSBezierPath(roundedRect: snipRect, xRadius: 12, yRadius: 12)
            NSColor(white: 1.0, alpha: 0.05).setFill()
            snipPath.fill()

            let snipText = NSAttributedString(string: snip, attributes: [
                .font: NSFont.systemFont(ofSize: 19, weight: .regular),
                .foregroundColor: NSColor.white
            ])
            snipText.draw(at: NSPoint(x: contentX + 16, y: snipY + 14))
        }

        // 4. Footer static notice
        drawFooterNotice(text: "Items auto-destruct in 5 minutes", x: contentX, y: y + 24, width: contentW)

    } else if pageIndex == 1 {
        // === PAGE 2: CONVERTER ===
        // 1. Input Drop Zone (y = y + 418, h = 140)
        let dropRect = NSRect(x: contentX, y: y + 418, width: contentW, height: 140)
        let dropPath = NSBezierPath(roundedRect: dropRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.05).setFill()
        dropPath.fill()
        NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.5).setStroke()
        dropPath.lineWidth = 2.0
        dropPath.stroke()

        let fileTitle = NSAttributedString(string: "landscape-hero.heic", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        fileTitle.draw(at: NSPoint(x: contentX + 90, y: y + 494))

        let fileMeta = NSAttributedString(string: "HEIC • 4.8 MB • Ready to convert", attributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor(white: 0.65, alpha: 1.0)
        ])
        fileMeta.draw(at: NSPoint(x: contentX + 90, y: y + 452))

        // 2. Options Card (y = y + 254, h = 148)
        let optRect = NSRect(x: contentX, y: y + 254, width: contentW, height: 148)
        let optPath = NSBezierPath(roundedRect: optRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.05).setFill()
        optPath.fill()

        let fmtLabel = NSAttributedString(string: "Format:   PNG   (Lossless)", attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor.white
        ])
        fmtLabel.draw(at: NSPoint(x: contentX + 24, y: y + 346))

        let qualLabel = NSAttributedString(string: "Quality:   [ High ]   Medium   Compressed", attributes: [
            .font: NSFont.systemFont(ofSize: 19, weight: .medium),
            .foregroundColor: NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        ])
        qualLabel.draw(at: NSPoint(x: contentX + 24, y: y + 288))

        // 3. Symmetrical Convert Button (y = y + 182, h = 56)
        let btnRect = NSRect(x: contentX, y: y + 182, width: contentW, height: 56)
        let btnPath = NSBezierPath(roundedRect: btnRect, xRadius: 16, yRadius: 16)
        NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0).setFill()
        btnPath.fill()

        let centerP = NSMutableParagraphStyle()
        centerP.alignment = .center
        let btnText = NSAttributedString(string: "Convert File", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: centerP
        ])
        btnText.draw(in: NSRect(x: contentX, y: y + 195, width: contentW, height: 32))

        // 4. Output Shelf (y = y + 26, h = 140)
        let outRect = NSRect(x: contentX, y: y + 26, width: contentW, height: 140)
        let outPath = NSBezierPath(roundedRect: outRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.05).setFill()
        outPath.fill()

        let outName = NSAttributedString(string: "landscape-hero-converted.png", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        outName.draw(at: NSPoint(x: contentX + 80, y: y + 102))

        let outMeta = NSAttributedString(string: "Ready • 3.2 MB • Drag out to Finder", attributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        ])
        outMeta.draw(at: NSPoint(x: contentX + 80, y: y + 62))

    } else if pageIndex == 2 {
        // === PAGE 3: COLOR SAMPLER ===
        // 1. Pick Button (y = y + 502, h = 56)
        let pickRect = NSRect(x: contentX, y: y + 502, width: contentW, height: 56)
        let pickPath = NSBezierPath(roundedRect: pickRect, xRadius: 16, yRadius: 16)
        NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0).setFill()
        pickPath.fill()

        let centerP = NSMutableParagraphStyle()
        centerP.alignment = .center
        let pickText = NSAttributedString(string: "Pick Screen Color (Loupe)", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: centerP
        ])
        pickText.draw(in: NSRect(x: contentX, y: y + 515, width: contentW, height: 32))

        // 2. Preview Card (y = y + 186, h = 300)
        let cardRect = NSRect(x: contentX, y: y + 186, width: contentW, height: 300)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.05).setFill()
        cardPath.fill()

        // Swatch (128x128 @2x)
        let swatchRect = NSRect(x: contentX + 28, y: y + 330, width: 128, height: 128)
        let swatchPath = NSBezierPath(roundedRect: swatchRect, xRadius: 16, yRadius: 16)
        NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0).setFill()
        swatchPath.fill()
        swatchPath.lineWidth = 2.0
        NSColor(white: 1.0, alpha: 0.3).setStroke()
        swatchPath.stroke()

        // Color Labels
        let hexStr = NSAttributedString(string: "#FF9F0F", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        hexStr.draw(at: NSPoint(x: contentX + 180, y: y + 412))

        let rgbStr = NSAttributedString(string: "rgb(255, 159, 15)", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .regular),
            .foregroundColor: NSColor(white: 0.75, alpha: 1.0)
        ])
        rgbStr.draw(at: NSPoint(x: contentX + 180, y: y + 372))

        let hslStr = NSAttributedString(string: "hsl(36, 100%, 53%)", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .regular),
            .foregroundColor: NSColor(white: 0.75, alpha: 1.0)
        ])
        hslStr.draw(at: NSPoint(x: contentX + 180, y: y + 334))

        // Copy buttons (width 170 each, 14pt gap)
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + 28, y: y + 214, width: 168, height: 52), title: "Copy HEX")
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + 212, y: y + 214, width: 168, height: 52), title: "Copy RGB")
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + 396, y: y + 214, width: 168, height: 52), title: "Copy HSL")

        // 3. Recents section (y = y + 120, h = 48)
        let recLabel = NSAttributedString(string: "Recent:", attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor(white: 0.55, alpha: 1.0)
        ])
        recLabel.draw(at: NSPoint(x: contentX + 12, y: y + 128))

        let recentColorsList = [
            NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0),
            NSColor(red: 0.18, green: 0.8, blue: 0.44, alpha: 1.0),
            NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.68, green: 0.32, blue: 0.87, alpha: 1.0),
            NSColor(red: 0.95, green: 0.25, blue: 0.35, alpha: 1.0)
        ]
        for (i, c) in recentColorsList.enumerated() {
            let swRect = NSRect(x: contentX + 105 + CGFloat(i) * 52, y: y + 124, width: 38, height: 38)
            let swPath = NSBezierPath(roundedRect: swRect, xRadius: 8, yRadius: 8)
            c.setFill()
            swPath.fill()
            swPath.lineWidth = 1.0
            NSColor(white: 1.0, alpha: 0.25).setStroke()
            swPath.stroke()
        }

        // 4. Toast label
        drawFooterNotice(text: "Auto-copied #FF9F0F to clipboard!", x: contentX, y: y + 24, width: contentW)

    } else if pageIndex == 3 {
        // === PAGE 4: QR CODE LAB ===
        // 1. Text Input row (y = y + 504, h = 52)
        let inputRect = NSRect(x: contentX, y: y + 504, width: contentW - 130, height: 52)
        let inputPath = NSBezierPath(roundedRect: inputRect, xRadius: 14, yRadius: 14)
        NSColor(white: 1.0, alpha: 0.06).setFill()
        inputPath.fill()
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        inputPath.stroke()

        let qrPlaceholder = NSAttributedString(string: "https://satset.dev/app", attributes: [
            .font: NSFont.systemFont(ofSize: 19, weight: .medium),
            .foregroundColor: NSColor.white
        ])
        qrPlaceholder.draw(at: NSPoint(x: contentX + 16, y: y + 518))

        drawMiniSquareButton(x: contentX + contentW - 120, y: y + 504, size: 52, icon: "doc.on.clipboard")
        drawMiniSquareButton(x: contentX + contentW - 58, y: y + 504, size: 52, icon: "xmark")

        // 2. Center Card & QR Preview (y = y + 88, h = 396)
        let cardRect = NSRect(x: contentX, y: y + 88, width: contentW, height: 396)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.05).setFill()
        cardPath.fill()

        // White QR backing card (240 x 240)
        let whiteCardRect = NSRect(x: contentX + (contentW - 240) / 2, y: y + 190, width: 240, height: 240)
        let whiteCard = NSBezierPath(roundedRect: whiteCardRect, xRadius: 16, yRadius: 16)
        NSColor.white.setFill()
        whiteCard.fill()

        // Simulated QR pattern
        let qrIconConfig = NSImage.SymbolConfiguration(pointSize: 170, weight: .bold)
        if let qrSym = NSImage(systemSymbolName: "qrcode", accessibilityDescription: nil)?.withSymbolConfiguration(qrIconConfig) {
            let qrDrawRect = NSRect(x: whiteCardRect.minX + 25, y: whiteCardRect.minY + 25, width: 190, height: 190)
            qrSym.draw(in: qrDrawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        // Action Buttons inside Card (width: 230 each, y = y + 110)
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + 24, y: y + 110, width: 230, height: 52), title: "Copy Image")
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + contentW - 254, y: y + 110, width: 230, height: 52), title: "Copy Text")

        // 3. Footer notice
        drawFooterNotice(text: "Drop image to scan • Drag QR to export", x: contentX, y: y + 24, width: contentW)

    } else if pageIndex == 4 {
        // === PAGE 5: SCREEN OCR & TEXT GRABBER ===
        // 1. Primary Snip Button (y = y + 502, h = 56)
        let snipRect = NSRect(x: contentX, y: y + 502, width: contentW, height: 56)
        let snipPath = NSBezierPath(roundedRect: snipRect, xRadius: 16, yRadius: 16)
        NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0).setFill()
        snipPath.fill()

        let centerP = NSMutableParagraphStyle()
        centerP.alignment = .center
        let snipText = NSAttributedString(string: "Snip Screen Text (Area)", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: centerP
        ])
        snipText.draw(in: NSRect(x: contentX, y: y + 515, width: contentW, height: 32))

        // 2. Text Content Card (y = y + 88, h = 396)
        let cardRect = NSRect(x: contentX, y: y + 88, width: contentW, height: 396)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.05).setFill()
        cardPath.fill()

        // OCR Result Snippet Lines
        let ocrLines = [
            "mini-satset v1.1.0 (Production Suite)",
            "Pure Swift & AppKit • Zero Dependencies",
            "Apple Vision On-Device Neural Engine",
            "100% Offline OCR • 0.0% Idle CPU"
        ]
        for (idx, line) in ocrLines.enumerated() {
            let lineY = y + 420 - CGFloat(idx) * 44
            let lineAttr = NSAttributedString(string: line, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: NSColor(white: 0.92, alpha: 1.0)
            ])
            lineAttr.draw(at: NSPoint(x: contentX + 24, y: lineY))
        }

        // Action Buttons inside Card (Copy Text & Clear)
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + 24, y: y + 110, width: 230, height: 52), title: "Copy Text")
        drawMiniActionCopyBtn(rect: NSRect(x: contentX + contentW - 254, y: y + 110, width: 230, height: 52), title: "Clear")

        // 3. Footer notice
        drawFooterNotice(text: "Select screen area to extract text • 100% offline", x: contentX, y: y + 24, width: contentW)
    }
}

func drawFileMiniCard(rect: NSRect, name: String, size: String, iconName: String) {
    let p = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
    NSColor(white: 1.0, alpha: 0.07).setFill()
    p.fill()

    let nameAttr = NSAttributedString(string: name, attributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: NSColor.white
    ])
    nameAttr.draw(at: NSPoint(x: rect.minX + 14, y: rect.minY + 44))

    let sizeAttr = NSAttributedString(string: size, attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular),
        .foregroundColor: NSColor(white: 0.65, alpha: 1.0)
    ])
    sizeAttr.draw(at: NSPoint(x: rect.minX + 14, y: rect.minY + 16))
}

func drawMiniSquareButton(x: CGFloat, y: CGFloat, size: CGFloat, icon: String) {
    let rect = NSRect(x: x, y: y, width: size, height: size)
    let p = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
    NSColor(white: 1.0, alpha: 0.08).setFill()
    p.fill()

    let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
    if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let iconW: CGFloat = 24
        let iconH: CGFloat = 24
        img.draw(in: NSRect(x: x + (size - iconW) / 2, y: y + (size - iconH) / 2, width: iconW, height: iconH), from: .zero, operation: .sourceOver, fraction: 0.9)
    }
}

func drawMiniActionCopyBtn(rect: NSRect, title: String) {
    let p = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
    NSColor(white: 1.0, alpha: 0.08).setFill()
    p.fill()

    let centerP = NSMutableParagraphStyle()
    centerP.alignment = .center
    let t = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: NSColor.white,
        .paragraphStyle: centerP
    ])
    t.draw(in: NSRect(x: rect.minX, y: rect.minY + 14, width: rect.width, height: 26))
}

func drawFooterNotice(text: String, x: CGFloat, y: CGFloat, width: CGFloat) {
    let centerP = NSMutableParagraphStyle()
    centerP.alignment = .center
    let notice = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: NSColor(white: 0.55, alpha: 1.0),
        .paragraphStyle: centerP
    ])
    notice.draw(in: NSRect(x: x, y: y, width: width, height: 26))
}

let args = CommandLine.arguments
let out = (args.count > 1) ? args[1] : "docs/images/mockup_preview.png"
generateMockup(outputPath: out)
