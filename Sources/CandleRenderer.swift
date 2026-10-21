import AppKit

/// Draws the candle. Everything is laid out on an 18-unit-tall grid and scaled,
/// so the same drawing works for the 18 pt menu bar icon and the big menu header.
enum CandleRenderer {
    static let menuBarSize = NSSize(width: 16, height: 18)

    /// - fraction: 1 = tall new candle, 0 = melted stub.
    /// - lit: whether the flame is burning.
    /// - flicker: alternate flame shape (used in the last minute).
    /// - tilt: rotation in radians around the base (used for the wiggle nudge).
    static func image(size: NSSize = menuBarSize,
                      fraction: Double,
                      lit: Bool,
                      flicker: Bool = false,
                      tilt: CGFloat = 0) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(in: rect, fraction: fraction, lit: lit, flicker: flicker, tilt: tilt)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = lit ? "Candle burning" : "Candle"
        return image
    }

    private static func draw(in rect: NSRect, fraction: Double, lit: Bool, flicker: Bool, tilt: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = rect.width
        let u = rect.height / 18.0
        let f = CGFloat(min(1, max(0, fraction)))

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // Wiggle: rotate around the bottom centre.
        if tilt != 0 {
            ctx.translateBy(x: w / 2, y: u)
            ctx.rotate(by: tilt)
            ctx.translateBy(x: -w / 2, y: -u)
        }

        // labelColor resolves to white on a dark menu bar and black on a light one.
        let ink = NSColor.labelColor

        // Plate
        let plateW = min(w - u, 12 * u)
        let plate = NSBezierPath(roundedRect: NSRect(x: (w - plateW) / 2, y: 0.4 * u, width: plateW, height: 1.3 * u),
                                 xRadius: 0.65 * u, yRadius: 0.65 * u)
        ink.withAlphaComponent(0.55).setFill()
        plate.fill()

        // Wax body: shrinks from 10 units tall to a 2-unit stub.
        let bodyW = 6.5 * u
        let bodyX = (w - bodyW) / 2
        let baseY = 1.5 * u
        let bodyH = 2 * u + 8 * u * f
        let bodyTop = baseY + bodyH
        let body = NSBezierPath(roundedRect: NSRect(x: bodyX, y: baseY, width: bodyW, height: bodyH),
                                xRadius: 1.1 * u, yRadius: 1.1 * u)
        ink.setFill()
        body.fill()

        // Wax drips appear as it melts.
        if f < 0.97 {
            let melted = 1 - f
            let dripLen = min(bodyH - u, (1.2 + 3.5 * melted) * u)
            let drip = NSBezierPath(roundedRect: NSRect(x: bodyX - 0.7 * u, y: bodyTop - dripLen, width: 1.6 * u, height: dripLen),
                                    xRadius: 0.8 * u, yRadius: 0.8 * u)
            drip.fill()
            if melted > 0.4 {
                let drip2Len = min(bodyH - u, (0.8 + 2.2 * melted) * u)
                let drip2 = NSBezierPath(roundedRect: NSRect(x: bodyX + bodyW - 0.9 * u, y: bodyTop - drip2Len, width: 1.5 * u, height: drip2Len),
                                         xRadius: 0.75 * u, yRadius: 0.75 * u)
                drip2.fill()
            }
        }

        // Wick
        let cx = w / 2
        let wick = NSBezierPath()
        wick.move(to: NSPoint(x: cx, y: bodyTop))
        wick.line(to: NSPoint(x: cx, y: bodyTop + 1.3 * u))
        wick.lineWidth = max(1, 0.7 * u)
        wick.lineCapStyle = .round
        ink.setStroke()
        wick.stroke()

        if lit {
            // Flame: a teardrop sitting on the wick.
            let fh = (flicker ? 4.0 : 5.0) * u
            let fw = (flicker ? 2.9 : 2.5) * u
            let fy = bodyTop + 0.9 * u
            let sway: CGFloat = flicker ? 0.6 * u : 0
            let flame = teardrop(cx: cx, baseY: fy, width: fw, height: fh, sway: sway)
            NSColor.systemOrange.setFill()
            flame.fill()
            let core = teardrop(cx: cx, baseY: fy + 0.2 * u, width: fw * 0.5, height: fh * 0.5, sway: sway * 0.5)
            NSColor.systemYellow.setFill()
            core.fill()
        } else if f < 0.05 {
            // Burnt out: a little wisp of smoke.
            let smoke = NSBezierPath()
            smoke.move(to: NSPoint(x: cx, y: bodyTop + 1.4 * u))
            smoke.curve(to: NSPoint(x: cx, y: bodyTop + 6 * u),
                        controlPoint1: NSPoint(x: cx + 2 * u, y: bodyTop + 2.8 * u),
                        controlPoint2: NSPoint(x: cx - 2 * u, y: bodyTop + 4.4 * u))
            smoke.lineWidth = max(1, 0.7 * u)
            smoke.lineCapStyle = .round
            NSColor.secondaryLabelColor.setStroke()
            smoke.stroke()
        }
    }

    private static func teardrop(cx: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat, sway: CGFloat) -> NSBezierPath {
        let tip = NSPoint(x: cx + sway, y: baseY + height)
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx, y: baseY))
        p.curve(to: tip,
                controlPoint1: NSPoint(x: cx + width, y: baseY + height * 0.05),
                controlPoint2: NSPoint(x: cx + width * 0.35, y: baseY + height * 0.75))
        p.curve(to: NSPoint(x: cx, y: baseY),
                controlPoint1: NSPoint(x: cx - width * 0.35, y: baseY + height * 0.75),
                controlPoint2: NSPoint(x: cx - width, y: baseY + height * 0.05))
        p.close()
        return p
    }
}
