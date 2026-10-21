import Foundation

/// Counts candles burnt today (resets at midnight) and all-time.
enum Streak {
    private static let dayKey = "streakDay"
    private static let countKey = "streakCount"
    private static let totalKey = "totalCandles"

    private static var todayStamp: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static var today: Int {
        let d = UserDefaults.standard
        return d.string(forKey: dayKey) == todayStamp ? d.integer(forKey: countKey) : 0
    }

    static var total: Int {
        UserDefaults.standard.integer(forKey: totalKey)
    }

    static func increment() {
        let d = UserDefaults.standard
        let newToday = today + 1
        d.set(todayStamp, forKey: dayKey)
        d.set(newToday, forKey: countKey)
        d.set(total + 1, forKey: totalKey)
    }

    static var todayText: String {
        switch today {
        case 0: return "No candles burnt yet today"
        case 1: return "Burnt 1 candle today 🕯️"
        default: return "Burnt \(today) candles today 🕯️"
        }
    }
}
