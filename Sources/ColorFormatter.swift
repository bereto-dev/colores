import Cocoa

enum ColorFormat: String, CaseIterable {
    case hex
    case rgb

    var label: String {
        switch self {
        case .hex: return "Hex"
        case .rgb: return "RGB"
        }
    }
}

enum ColorFormatter {
    struct Components {
        let r: Int
        let g: Int
        let b: Int
    }

    static func components(of color: NSColor) -> Components? {
        guard let converted = color.usingColorSpace(.sRGB) else { return nil }
        return Components(
            r: Int((converted.redComponent * 255).rounded()),
            g: Int((converted.greenComponent * 255).rounded()),
            b: Int((converted.blueComponent * 255).rounded())
        )
    }

    static func hexString(from color: NSColor) -> String? {
        guard let c = components(of: color) else { return nil }
        return String(format: "#%02X%02X%02X", c.r, c.g, c.b)
    }

    static func rgbString(from color: NSColor) -> String? {
        guard let c = components(of: color) else { return nil }
        return "rgb(\(c.r), \(c.g), \(c.b))"
    }

    static func string(from color: NSColor, format: ColorFormat) -> String? {
        switch format {
        case .hex: return hexString(from: color)
        case .rgb: return rgbString(from: color)
        }
    }

    static func color(fromHex hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
