import AppKit
import SwiftUI

struct BatteryIconState: Equatable {
    var level: Int
    var chargingMode: ChargingMode
    var isLowPowerModeEnabled: Bool
    var percentageDisplayLocation: PercentageDisplayLocation
    var showsLowBatteryWarning: Bool

    var accessibilityDescription: String {
        var parts = [String(localized: "Battery \(clampedLevel) percent")]
        switch chargingMode {
        case .charging: parts.append(String(localized: "charging"))
        case .pluggedIn: parts.append(String(localized: "plugged in"))
        case .discharging: break
        }
        if isLowPowerModeEnabled { parts.append(String(localized: "low power mode")) }
        return parts.joined(separator: ", ")
    }

    fileprivate var clampedLevel: Int { min(max(level, 0), 100) }

    fileprivate var accent: BatteryAccent? {
        if showsLowBatteryWarning && clampedLevel <= 20 { return .critical }
        if isLowPowerModeEnabled { return .lowPower }
        if chargingMode == .charging { return .charging }
        return nil
    }

    fileprivate var statusSymbol: StatusSymbol? {
        switch chargingMode {
        case .charging: .bolt
        case .pluggedIn: .plug
        case .discharging: nil
        }
    }
}

private enum BatteryAccent {
    case critical
    case lowPower
    case charging

    var color: NSColor {
        switch self {
        case .critical: .systemRed
        case .lowPower: .systemYellow
        case .charging: .systemGreen
        }
    }

    // A cut-out label shows the menu bar through the fill, which is unreadable on yellow in a light menu bar.
    var knocksOutLabel: Bool { self != .lowPower }
}

private enum StatusSymbol: CaseIterable {
    case bolt
    case plug

    var image: NSImage? {
        let name =
            switch self {
            case .bolt: "bolt.fill"
            case .plug: "powerplug.fill"
            }
        // Render the vector glyph large and let drawing scale it down so the weight is independent of size.
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 64, weight: weight))
    }

    // Heavier plug weights fill in the gap between the prongs at menu bar sizes.
    private var weight: NSFont.Weight {
        switch self {
        case .bolt: .black
        case .plug: .bold
        }
    }

    var rotation: CGFloat {
        switch self {
        case .bolt: 0
        case .plug: .pi / 2
        }
    }

    // The plug is visually heavier than the bolt, so it is drawn slightly smaller to look balanced.
    private var heightScale: CGFloat {
        switch self {
        case .bolt: 1
        case .plug: 0.9
        }
    }

    // Symbol images pad the glyph on every side. Sizing and centering by the drawn glyph instead keeps the
    // symbol at the intended height and the label optically centered.
    private static let glyphFractions: [StatusSymbol: CGSize] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0, $0.measureGlyphFraction()) })

    private func measureGlyphFraction() -> CGSize {
        let fallback = CGSize(width: 1, height: 1)
        guard let image, image.size.width > 0, image.size.height > 0,
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(image.size.width.rounded(.up)),
                pixelsHigh: Int(image.size.height.rounded(.up)),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return fallback }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()

        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard minX <= maxX, minY <= maxY else { return fallback }
        return CGSize(
            width: CGFloat(maxX - minX + 1) / CGFloat(bitmap.pixelsWide),
            height: CGFloat(maxY - minY + 1) / CGFloat(bitmap.pixelsHigh)
        )
    }

    // The unrotated image size whose glyph, once rotated, is `height` tall.
    func imageSize(glyphHeight height: CGFloat) -> CGSize {
        guard let size = image?.size, size.width > 0, size.height > 0 else {
            return CGSize(width: height, height: height)
        }
        let fraction = Self.glyphFractions[self] ?? CGSize(width: 1, height: 1)
        let height = height * heightScale
        if rotation == 0 {
            let imageHeight = height / fraction.height
            return CGSize(width: imageHeight * size.width / size.height, height: imageHeight)
        }
        let imageWidth = height / fraction.width
        return CGSize(width: imageWidth, height: imageWidth * size.height / size.width)
    }

    // The visible glyph size, after rotation, when drawn at `height`.
    func glyphSize(height: CGFloat) -> CGSize {
        let imageSize = imageSize(glyphHeight: height)
        let fraction = Self.glyphFractions[self] ?? CGSize(width: 1, height: 1)
        let glyph = CGSize(
            width: imageSize.width * fraction.width, height: imageSize.height * fraction.height)
        return rotation == 0 ? glyph : CGSize(width: glyph.height, height: glyph.width)
    }
}

enum BatteryIcon {
    private enum Outline {
        static let bodySize = CGSize(width: 24, height: 12)
        static let cornerRadius: CGFloat = 3.5
        static let strokeOpacity: CGFloat = 0.4
        static let fillInset: CGFloat = 2
        static let terminalSize = CGSize(width: 1.5, height: 4)
        static let symbolHeight: CGFloat = 8
        static let symbolHalo: CGFloat = 1
    }

    private enum Inside {
        static let bodySize = CGSize(width: 28, height: 13)
        static let cornerRadius: CGFloat = 4
        static let trackOpacity: CGFloat = 0.35
        static let terminalSize = CGSize(width: 1.5, height: 5)
        static let fontSize: CGFloat = 10.5
        static let symbolHeight: CGFloat = 9.5
        static let symbolSpacing: CGFloat = 2
    }

    private static let terminalSpacing: CGFloat = 1
    private static let terminalOpacity: CGFloat = 0.4
    private static let verticalPadding: CGFloat = 1

    @MainActor
    static func image(for state: BatteryIconState) -> NSImage {
        let isInside = state.percentageDisplayLocation == .insideIcon
        let size = isInside ? insideSize : outlineSize
        let image = NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // The knockouts use destination-out blending. The layer confines them to the icon so they
            // never cut through what AppKit drew underneath, like the highlighted button background.
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            if isInside {
                drawInsideBattery(state, in: bounds, context: context)
            } else {
                drawOutlineBattery(state, in: bounds, context: context)
            }
            context.endTransparencyLayer()
            return true
        }
        // A template image lets the menu bar apply its own tint, vibrancy, and inactive-display dimming.
        // Colored states can't be expressed as a template and resolve dynamic colors at draw time instead.
        image.isTemplate = state.accent == nil
        image.accessibilityDescription = state.accessibilityDescription
        return image
    }

    private static var outlineSize: CGSize {
        CGSize(
            width: (Outline.bodySize.width + terminalSpacing + Outline.terminalSize.width).rounded(.up),
            height: Outline.bodySize.height + verticalPadding * 2
        )
    }

    private static var insideSize: CGSize {
        CGSize(
            width: (Inside.bodySize.width + terminalSpacing + Inside.terminalSize.width).rounded(.up),
            height: Inside.bodySize.height + verticalPadding * 2
        )
    }

    // Template rendering only reads alpha, so a fully opaque label color keeps both rendering modes equally bright.
    private static var inkColor: CGColor {
        NSColor.labelColor.withAlphaComponent(1).cgColor
    }

    private static func drawOutlineBattery(
        _ state: BatteryIconState, in bounds: CGRect, context: CGContext
    ) {
        let ink = inkColor
        let body = CGRect(
            origin: CGPoint(x: 0, y: (bounds.height - Outline.bodySize.height) / 2),
            size: Outline.bodySize
        )

        context.setLineWidth(1)
        context.setStrokeColor(ink.copy(alpha: Outline.strokeOpacity) ?? ink)
        context.addPath(
            roundedPath(body.insetBy(dx: 0.5, dy: 0.5), cornerRadius: Outline.cornerRadius - 0.5))
        context.strokePath()

        drawTerminal(attachedTo: body, size: Outline.terminalSize, color: ink, context: context)

        let track = body.insetBy(dx: Outline.fillInset, dy: Outline.fillInset)
        let fillWidth = levelWidth(state.clampedLevel, of: track.width, context: context)
        if fillWidth > 0 {
            let fill = CGRect(x: track.minX, y: track.minY, width: fillWidth, height: track.height)
            context.setFillColor(state.accent?.color.cgColor ?? ink)
            context.addPath(
                roundedPath(
                    fill,
                    cornerRadius: min(Outline.cornerRadius - Outline.fillInset, fillWidth / 2)))
            context.fillPath()
        }

        if let symbol = state.statusSymbol {
            let center = CGPoint(x: body.midX, y: body.midY)
            knockOut(context: context) {
                for angle in stride(from: 0, to: 2 * CGFloat.pi, by: CGFloat.pi / 4) {
                    let offset = CGPoint(
                        x: center.x + cos(angle) * Outline.symbolHalo,
                        y: center.y + sin(angle) * Outline.symbolHalo
                    )
                    drawSymbol(
                        symbol, glyphHeight: Outline.symbolHeight, centeredAt: offset, color: ink,
                        context: context)
                }
            }
            drawSymbol(
                symbol, glyphHeight: Outline.symbolHeight, centeredAt: center, color: ink,
                context: context)
        }
    }

    private static func drawInsideBattery(
        _ state: BatteryIconState, in bounds: CGRect, context: CGContext
    ) {
        let ink = inkColor
        let body = CGRect(
            origin: CGPoint(x: 0, y: (bounds.height - Inside.bodySize.height) / 2),
            size: Inside.bodySize
        )
        let bodyPath = roundedPath(body, cornerRadius: Inside.cornerRadius)

        context.saveGState()
        context.addPath(bodyPath)
        context.clip()

        context.setFillColor(ink.copy(alpha: Inside.trackOpacity) ?? ink)
        context.fill(body)

        let fillWidth = levelWidth(state.clampedLevel, of: body.width, context: context)
        context.setFillColor(state.accent?.color.cgColor ?? ink)
        context.fill(CGRect(x: body.minX, y: body.minY, width: fillWidth, height: body.height))

        if state.accent?.knocksOutLabel ?? true {
            knockOut(context: context) {
                drawLabel(state, centeredIn: body, color: ink, context: context)
            }
        } else {
            drawLabel(state, centeredIn: body, color: NSColor.black.cgColor, context: context)
        }
        context.restoreGState()

        drawTerminal(attachedTo: body, size: Inside.terminalSize, color: ink, context: context)
    }

    private static func drawTerminal(
        attachedTo body: CGRect, size: CGSize, color: CGColor, context: CGContext
    ) {
        let rect = CGRect(
            x: body.maxX + terminalSpacing,
            y: body.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let path = UnevenRoundedRectangle(
            bottomTrailingRadius: size.width,
            topTrailingRadius: size.width,
            style: .continuous
        ).path(in: rect).cgPath
        context.setFillColor(color.copy(alpha: terminalOpacity) ?? color)
        context.addPath(path)
        context.fillPath()
    }

    private static func drawLabel(
        _ state: BatteryIconState, centeredIn rect: CGRect, color: CGColor, context: CGContext
    ) {
        let level = state.clampedLevel
        // Condensed digits leave room for "100" and a status symbol with even padding at a legible size.
        let font = NSFont.systemFont(ofSize: Inside.fontSize, weight: .bold, width: .condensed)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: "\(level)", attributes: attributes))
        let inkBounds = CTLineGetImageBounds(line, context)
        let symbolSize = state.statusSymbol?.glyphSize(height: Inside.symbolHeight) ?? .zero
        let symbolSpacing = state.statusSymbol == nil ? 0 : Inside.symbolSpacing
        let labelMinX = rect.midX - (inkBounds.width + symbolSpacing + symbolSize.width) / 2

        context.saveGState()
        context.textMatrix = .identity
        context.setFillColor(color)
        // Center the glyph ink rather than the line box so the label sits optically centered in the body.
        context.textPosition = CGPoint(
            x: labelMinX - inkBounds.minX,
            y: snapToPixel(rect.midY - inkBounds.midY, context: context)
        )
        CTLineDraw(line, context)
        context.restoreGState()

        if let symbol = state.statusSymbol {
            let center = CGPoint(
                x: labelMinX + inkBounds.width + symbolSpacing + symbolSize.width / 2,
                y: rect.midY
            )
            drawSymbol(
                symbol, glyphHeight: Inside.symbolHeight, centeredAt: center, color: color,
                context: context)
        }
    }

    private static func drawSymbol(
        _ symbol: StatusSymbol, glyphHeight: CGFloat, centeredAt center: CGPoint, color: CGColor,
        context: CGContext
    ) {
        guard let image = symbol.image else { return }
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: symbol.rotation)
        let drawSize = symbol.imageSize(glyphHeight: glyphHeight)
        let drawRect = CGRect(
            x: -drawSize.width / 2, y: -drawSize.height / 2,
            width: drawSize.width, height: drawSize.height)
        image.draw(in: drawRect)
        context.setBlendMode(.sourceIn)
        context.setFillColor(color)
        context.fill(drawRect.insetBy(dx: -1, dy: -1))
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func knockOut(context: CGContext, _ draw: () -> Void) {
        context.saveGState()
        context.setBlendMode(.destinationOut)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        draw()
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func levelWidth(_ level: Int, of width: CGFloat, context: CGContext) -> CGFloat {
        guard level > 0 else { return 0 }
        let pixel = 1 / pixelScale(of: context)
        return max(snapToPixel(width * CGFloat(level) / 100, context: context), pixel * 2)
    }

    private static func snapToPixel(_ value: CGFloat, context: CGContext) -> CGFloat {
        let scale = pixelScale(of: context)
        return (value * scale).rounded() / scale
    }

    private static func pixelScale(of context: CGContext) -> CGFloat {
        max(1, abs(context.userSpaceToDeviceSpaceTransform.a))
    }

    private static func roundedPath(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        Path(roundedRect: rect, cornerRadius: max(0, cornerRadius), style: .continuous).cgPath
    }
}

#Preview {
    let levels = [100, 80, 50, 20, 5]
    let modes: [ChargingMode] = [.discharging, .charging, .pluggedIn]
    VStack(alignment: .leading, spacing: 12) {
        ForEach(
            [PercentageDisplayLocation.hidden, .insideIcon], id: \.self
        ) { location in
            ForEach(levels, id: \.self) { level in
                HStack(spacing: 16) {
                    ForEach(modes, id: \.self) { mode in
                        Image(
                            nsImage: BatteryIcon.image(
                                for: BatteryIconState(
                                    level: level,
                                    chargingMode: mode,
                                    isLowPowerModeEnabled: false,
                                    percentageDisplayLocation: location,
                                    showsLowBatteryWarning: true
                                ))
                        )
                    }
                }
            }
        }
    }
    .padding()
}
