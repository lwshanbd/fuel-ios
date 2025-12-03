import Foundation
import SwiftUI

/// ViewModel for calculating and managing vehicle statistics
@Observable
class StatisticsViewModel {
    private var records: [FuelingRecord]

    init(records: [FuelingRecord]) {
        self.records = records
    }

    func updateRecords(_ records: [FuelingRecord]) {
        self.records = records
    }

    // MARK: - Helper Methods

    /// Get the previous miles for a given record (from the record before it in date order)
    private func previousMiles(for record: FuelingRecord) -> Double {
        let sortedByDate = records.sorted { $0.date < $1.date }
        guard let index = sortedByDate.firstIndex(where: { $0.id == record.id }),
              index > 0 else {
            return 0
        }
        return sortedByDate[index - 1].currentMiles
    }

    /// Calculate miles driven for a record
    private func milesDriven(for record: FuelingRecord) -> Double {
        record.milesDriven(previousMiles: previousMiles(for: record))
    }

    /// Calculate MPG for a record
    private func mpg(for record: FuelingRecord) -> Double {
        record.mpg(previousMiles: previousMiles(for: record))
    }

    // MARK: - Basic Statistics

    var totalSpent: Double {
        records.reduce(0) { $0 + $1.totalCost }
    }

    var totalMiles: Double {
        records.reduce(0) { $0 + milesDriven(for: $1) }
    }

    var totalGallons: Double {
        records.reduce(0) { $0 + $1.gallons }
    }

    var totalFillUps: Int {
        records.count
    }

    // MARK: - Averages

    var averageMPG: Double {
        let fullFillUps = records.filter { !$0.isPartialFillUp }
        guard !fullFillUps.isEmpty else {
            guard totalGallons > 0 else { return 0 }
            return totalMiles / totalGallons
        }

        let fullMiles = fullFillUps.reduce(0) { $0 + milesDriven(for: $1) }
        let fullGallons = fullFillUps.reduce(0) { $0 + $1.gallons }
        guard fullGallons > 0 else { return 0 }
        return fullMiles / fullGallons
    }

    var averageCostPerMile: Double {
        guard totalMiles > 0 else { return 0 }
        return totalSpent / totalMiles
    }

    var averageFillUpCost: Double {
        guard !records.isEmpty else { return 0 }
        return totalSpent / Double(records.count)
    }

    var averagePricePerGallon: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.pricePerGallon } / Double(records.count)
    }

    var averageGallonsPerFillUp: Double {
        guard !records.isEmpty else { return 0 }
        return totalGallons / Double(records.count)
    }

    // MARK: - Time-based Statistics

    var lastFillUpDate: Date? {
        records.max(by: { $0.date < $1.date })?.date
    }

    var daysSinceLastFillUp: Int? {
        guard let lastDate = lastFillUpDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }

    // MARK: - Monthly Statistics

    func monthlySpending(for month: Date) -> Double {
        records.records(forMonth: month).totalCost
    }

    func monthlyMiles(for month: Date) -> Double {
        records.records(forMonth: month).totalMiles
    }

    func monthlyGallons(for month: Date) -> Double {
        records.records(forMonth: month).totalGallons
    }

    // MARK: - Best/Worst Statistics

    var bestMPG: Double? {
        let fullFillUps = records.filter { !$0.isPartialFillUp }
        guard !fullFillUps.isEmpty else { return nil }
        return fullFillUps.map { mpg(for: $0) }.max()
    }

    var worstMPG: Double? {
        let fullFillUps = records.filter { !$0.isPartialFillUp }
        guard !fullFillUps.isEmpty else { return nil }
        return fullFillUps.map { mpg(for: $0) }.min()
    }

    var highestPricePerGallon: Double? {
        records.max(by: { $0.pricePerGallon < $1.pricePerGallon })?.pricePerGallon
    }

    var lowestPricePerGallon: Double? {
        records.min(by: { $0.pricePerGallon < $1.pricePerGallon })?.pricePerGallon
    }

    var mostExpensiveFillUp: FuelingRecord? {
        records.max(by: { $0.totalCost < $1.totalCost })
    }

    var cheapestFillUp: FuelingRecord? {
        records.min(by: { $0.totalCost < $1.totalCost })
    }

    // MARK: - Trends

    /// Calculate the trend in MPG over the last N records
    func mpgTrend(lastN: Int = 5) -> TrendDirection {
        let recentRecords = Array(records.filter { !$0.isPartialFillUp }.prefix(lastN))
        guard recentRecords.count >= 2 else { return .stable }

        let recentAvg = recentRecords.reduce(0) { $0 + mpg(for: $1) } / Double(recentRecords.count)
        let overallAvg = averageMPG

        let difference = recentAvg - overallAvg
        let threshold = overallAvg * 0.05 // 5% threshold

        if difference > threshold {
            return .improving
        } else if difference < -threshold {
            return .declining
        }
        return .stable
    }

    /// Calculate the trend in cost per gallon over the last N records
    func priceTrend(lastN: Int = 5) -> TrendDirection {
        let recentRecords = Array(records.prefix(lastN))
        guard recentRecords.count >= 2 else { return .stable }

        let recentAvg = recentRecords.reduce(0) { $0 + $1.pricePerGallon } / Double(recentRecords.count)
        let overallAvg = averagePricePerGallon

        let difference = recentAvg - overallAvg
        let threshold = overallAvg * 0.05

        if difference > threshold {
            return .increasing
        } else if difference < -threshold {
            return .decreasing
        }
        return .stable
    }

    enum TrendDirection {
        case improving
        case declining
        case stable
        case increasing
        case decreasing

        var icon: String {
            switch self {
            case .improving, .decreasing:
                return "arrow.up.right"
            case .declining, .increasing:
                return "arrow.down.right"
            case .stable:
                return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .improving, .decreasing:
                return .green
            case .declining, .increasing:
                return .red
            case .stable:
                return .secondary
            }
        }
    }

    // MARK: - Chart Data

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let label: String
    }

    func mpgChartData() -> [ChartDataPoint] {
        records.filter { !$0.isPartialFillUp }
            .sorted { $0.date < $1.date }
            .map { record in
                let mpgValue = mpg(for: record)
                return ChartDataPoint(date: record.date, value: mpgValue, label: "\(mpgValue.formatted(decimals: 1)) MPG")
            }
    }

    func costChartData() -> [ChartDataPoint] {
        records.sorted { $0.date < $1.date }
            .map { ChartDataPoint(date: $0.date, value: $0.totalCost, label: $0.totalCost.currencyFormatted) }
    }

    func priceChartData() -> [ChartDataPoint] {
        records.sorted { $0.date < $1.date }
            .map { ChartDataPoint(date: $0.date, value: $0.pricePerGallon, label: $0.pricePerGallon.currencyFormatted) }
    }
}

