import AppKit

struct ColorFormats {
    let hex: String
    let rgb: String
    let hsl: String
}

enum ColorFormatHelper {
    static func formats(from color: NSColor) -> ColorFormats {
        guard let srgb = color.usingColorSpace(.sRGB) else {
            return ColorFormats(hex: "#000000", rgb: "rgb(0, 0, 0)", hsl: "hsl(0, 0%, 0%)")
        }

        let r = Int(round(srgb.redComponent * 255))
        let g = Int(round(srgb.greenComponent * 255))
        let b = Int(round(srgb.blueComponent * 255))

        let hex = String(format: "#%02X%02X%02X", r, g, b)
        let rgb = "rgb(\(r), \(g), \(b))"

        // HSL calculation
        let rf = srgb.redComponent
        let gf = srgb.greenComponent
        let bf = srgb.blueComponent

        let maxVal = max(rf, gf, bf)
        let minVal = min(rf, gf, bf)
        let delta = maxVal - minVal

        var h: CGFloat = 0
        var s: CGFloat = 0
        let l: CGFloat = (maxVal + minVal) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal)

            if maxVal == rf {
                h = (gf - bf) / delta + (gf < bf ? 6.0 : 0.0)
            } else if maxVal == gf {
                h = (bf - rf) / delta + 2.0
            } else {
                h = (rf - gf) / delta + 4.0
            }
            h /= 6.0
        }

        let hDeg = Int(round(h * 360))
        let sPct = Int(round(s * 100))
        let lPct = Int(round(l * 100))
        let hsl = "hsl(\(hDeg), \(sPct)%, \(lPct)%)"

        return ColorFormats(hex: hex, rgb: rgb, hsl: hsl)
    }
}
