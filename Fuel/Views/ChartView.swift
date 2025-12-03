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

    private var fullFillUpRecords: [FuelingRecord] {
        records.filter { !$0.isPartialFillUp }
    }

    /// Get the previous miles for a given record
    private func previousMiles(for record: FuelingRecord) -> Double {
        let sortedByDate = records.sorted { $0.date < $1.date }
        guard let index = sortedByDate.firstIndex(where: { $0.id == record.id }),
              index > 0 else {
            return 0
        }
        return sortedByDate[index - 1].currentMiles
    }

    private var averageMPG: Double {
        guard !fullFillUpRecords.isEmpty else { return 0 }
        return fullFillUpRecords.reduce(0) { $0 + $1.mpg(previousMiles: previousMiles(for: $1)) } / Double(fullFillUpRecords.count)
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
                ForEach(fullFillUpRecords, id: \.id) { record in
                    let mpg = record.mpg(previousMiles: previousMiles(for: record))
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
                        y: .value("MPG", mpg)
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
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }
}

struct CostChart: View {
    let records: [FuelingRecord]

    private var averageCost: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.totalCost } / Double(records.count)
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
                ForEach(records, id: \.id) { record in
                    BarMark(
                        x: .value("Date", record.date),
                        y: .value("Cost", record.totalCost)
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
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }
}

struct PricePerGallonChart: View {
    let records: [FuelingRecord]

    private var averagePrice: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.pricePerGallon } / Double(records.count)
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
                ForEach(records, id: \.id) { record in
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
                        y: .value("Price", record.pricePerGallon)
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
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }
}

#Preview {
    ChartView(records: [])
        .padding()
}

