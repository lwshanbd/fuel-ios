import Foundation
import SwiftUI

// MARK: - Double Extensions

extension Double {
    /// Format as currency (e.g., $3.45)
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    /// Format with specific decimal places
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is within this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is within this month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Get relative description (Today, Yesterday, or date)
    var relativeDescription: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string is a valid number
    var isNumeric: Bool {
        Double(self) != nil
    }

    /// Trim whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Array Extensions

extension Array where Element == FuelingRecord {
    /// Get records within a date range
    func records(from startDate: Date, to endDate: Date) -> [FuelingRecord] {
        filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Get records for a specific month
    func records(forMonth date: Date) -> [FuelingRecord] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) else {
            return []
        }
        return records(from: startOfMonth, to: endOfMonth)
    }

    /// Get the previous miles for a given record (from the record before it in date order)
    func previousMiles(for record: FuelingRecord) -> Double {
        let sortedByDate = sorted { $0.date < $1.date }
        guard let index = sortedByDate.firstIndex(where: { $0.id == record.id }),
              index > 0 else {
            return 0
        }
        return sortedByDate[index - 1].currentMiles
    }

    /// Calculate total cost for records
    var totalCost: Double {
        reduce(0) { $0 + $1.totalCost }
    }

    /// Calculate total miles for records
    var totalMiles: Double {
        reduce(0) { $0 + $1.milesDriven(previousMiles: previousMiles(for: $1)) }
    }

    /// Calculate total gallons for records
    var totalGallons: Double {
        reduce(0) { $0 + $1.gallons }
    }
}

