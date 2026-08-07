import Foundation

enum ColorPreferences {
    private static let defaults = UserDefaults.standard
    private static let formatKey = "colorFormat"
    private static let historyKey = "colorHistory"
    private static let maxHistory = 6

    static var format: ColorFormat {
        get {
            guard let raw = defaults.string(forKey: formatKey), let f = ColorFormat(rawValue: raw) else {
                return .hex
            }
            return f
        }
        set { defaults.set(newValue.rawValue, forKey: formatKey) }
    }

    static var history: [String] {
        defaults.stringArray(forKey: historyKey) ?? []
    }

    static func pushHistory(hex: String) {
        var items = history
        items.removeAll { $0 == hex }
        items.insert(hex, at: 0)
        if items.count > maxHistory {
            items.removeLast(items.count - maxHistory)
        }
        defaults.set(items, forKey: historyKey)
    }

    static func removeHistory(hex: String) {
        var items = history
        items.removeAll { $0 == hex }
        defaults.set(items, forKey: historyKey)
    }

    static func clearHistory() {
        defaults.removeObject(forKey: historyKey)
    }
}
