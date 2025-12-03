import SwiftUI
import Charts

struct ChartView: View {
    let records: [FuelingRecord]

    @State private var selectedChart: ChartType = .mpg

    enum ChartType: String, CaseIterable {
        case mpg = "MPG"
        case cost = "Cost"
        case pricePerGallon = "$/Gallon"
    }

    private var sortedRecords: [FuelingRecord] {
        records.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Chart Type Picker
            Picker("Chart Type", selection: $selectedChart) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.rawValue)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Chart
            Group {
                switch selectedChart {
                case .mpg:
                    MPGChart(records: sortedRecords)
                case .cost:
                    CostChart(records: sortedRecords)
                case .pricePerGallon:
                    PricePerGallonChart(records: sortedRecords)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct MPGChart: View {
    let records: [FuelingRecord]

    /// Records that have valid cached MPG values
    private var validMPGRecords: [FuelingRecord] {
        records
            .filter { $0.cachedMPG != nil && $0.cachedMPG! > 0 }
            .sorted { $0.date < $1.date }
    }

    private var averageMPG: Double {
        guard !validMPGRecords.isEmpty else { return 0 }
        let totalMPG = validMPGRecords.reduce(0.0) { $0 + ($1.cachedMPG ?? 0) }
        return totalMPG / Double(validMPGRecords.count)
    }

    /// Calculate Y-axis range rounded to multiples of 5
    private var yAxisRange: ClosedRange<Double> {
        let mpgValues = validMPGRecords.compactMap { $0.cachedMPG }
        guard let minValue = mpgValues.min(), let maxValue = mpgValues.max() else {
            return 0...40
        }
        // Round down to nearest 5 for min, round up to nearest 5 for max
        let minY = floor(minValue / 5) * 5
        let maxY = ceil(maxValue / 5) * 5
        // Ensure there's at least some padding
        return minY...max(maxY, minY + 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Miles Per Gallon")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Avg: \(averageMPG.formatted(.number.precision(.fractionLength(1)))) MPG")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundColor(.purple)
            }

            Chart {
                ForEach(validMPGRecords, id: \.id) { record in
                    let mpg = record.cachedMPG ?? 0
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("MPG", mpg)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", record.date),
                        yStart: .value("Min", yAxisRange.lowerBound),
                        yEnd: .value("MPG", mpg)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .purple.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("MPG", mpg)
                    )
                    .foregroundStyle(.purple)
                    .symbolSize(40)
                }

                // Average line
                RuleMark(y: .value("Average", averageMPG))
                    .foregroundStyle(.purple.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: yAxisRange)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                }
            }
        }
    }
}

struct CostChart: View {
    let records: [FuelingRecord]

    // Pre-sorted records for chart display
    private var sortedRecords: [FuelingRecord] {
        records.sorted { $0.date < $1.date }
    }

    private var averageCost: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.totalCost } / Double(records.count)
    }

    /// Calculate Y-axis range rounded to multiples of 10
    private var yAxisRange: ClosedRange<Double> {
        let costValues = records.map { $0.totalCost }
        guard let minValue = costValues.min(), let maxValue = costValues.max() else {
            return 0...100
        }
        // Round down to nearest 10 for min, round up to nearest 10 for max
        let minY = floor(minValue / 10) * 10
        let maxY = ceil(maxValue / 10) * 10
        // Ensure there's at least some padding
        return minY...max(maxY, minY + 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cost per Fill-up")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Avg: \(averageCost.currencyFormatted)")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundColor(.orange)
            }

            Chart {
                ForEach(sortedRecords, id: \.id) { record in
                    BarMark(
                        x: .value("Date", record.date),
                        yStart: .value("Min", yAxisRange.lowerBound),
                        yEnd: .value("Cost", record.totalCost)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }

                // Average line
                RuleMark(y: .value("Average", averageCost))
                    .foregroundStyle(.orange.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: yAxisRange)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(cost.currencyFormatted)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                }
            }
        }
    }
}

struct PricePerGallonChart: View {
    let records: [FuelingRecord]

    // Pre-sorted records for chart display
    private var sortedRecords: [FuelingRecord] {
        records.sorted { $0.date < $1.date }
    }

    private var averagePrice: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.pricePerGallon } / Double(records.count)
    }

    /// Calculate Y-axis range rounded to multiples of 0.5
    private var yAxisRange: ClosedRange<Double> {
        let priceValues = records.map { $0.pricePerGallon }
        guard let minValue = priceValues.min(), let maxValue = priceValues.max() else {
            return 0...5
        }
        // Round down to nearest 0.5 for min, round up to nearest 0.5 for max
        let minY = floor(minValue * 2) / 2
        let maxY = ceil(maxValue * 2) / 2
        // Ensure there's at least some padding
        return minY...max(maxY, minY + 0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Price per Gallon")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Avg: \(averagePrice.currencyFormatted)")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundColor(.green)
            }

            Chart {
                ForEach(sortedRecords, id: \.id) { record in
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Price", record.pricePerGallon)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", record.date),
                        yStart: .value("Min", yAxisRange.lowerBound),
                        yEnd: .value("Price", record.pricePerGallon)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Price", record.pricePerGallon)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(40)
                }

                // Average line
                RuleMark(y: .value("Average", averagePrice))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: yAxisRange)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text(price.currencyFormatted)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                }
            }
        }
    }
}

#Preview {
    ChartView(records: [])
        .padding()
}

