import Foundation

/// Service for handling CSV import and export of fueling records
enum CSVService {

    // MARK: - Export

    /// Export fueling records to CSV format
    /// - Parameter records: Array of FuelingRecord to export
    /// - Returns: CSV formatted string
    static func exportRecords(_ records: [FuelingRecord]) -> String {
        var csv = FuelingRecord.csvHeader + "\n"

        for record in records.sorted(by: { $0.date < $1.date }) {
            csv += record.toCSVRow() + "\n"
        }

        return csv
    }

    /// Export multiple vehicles and their records to CSV format
    /// - Parameter vehicles: Array of Vehicle to export
    /// - Returns: CSV formatted string containing all vehicles' records
    static func exportAllVehicles(_ vehicles: [Vehicle]) -> String {
        var csv = "vehicleName,vehicleMake,vehicleModel,vehicleYear," + FuelingRecord.csvHeader + "\n"

        for vehicle in vehicles {
            for record in vehicle.sortedRecords {
                let vehicleInfo = "\"\(vehicle.name)\",\"\(vehicle.make ?? "")\",\"\(vehicle.model ?? "")\",\(vehicle.year ?? 0),"
                csv += vehicleInfo + record.toCSVRow() + "\n"
            }
        }

        return csv
    }

    // MARK: - Import

    /// Import fueling records from CSV content
    /// - Parameter content: CSV formatted string
    /// - Returns: Array of FuelingRecord parsed from CSV
    static func importRecords(from content: String) -> [FuelingRecord] {
        var records: [FuelingRecord] = []

        let lines = content.components(separatedBy: .newlines)

        // Skip header row
        let dataLines = lines.dropFirst().filter { !$0.isEmpty }

        for line in dataLines {
            if let record = FuelingRecord.fromCSVRow(line) {
                records.append(record)
            }
        }

        return records
    }

    /// Parse a simple CSV file format (for manual data entry or basic imports)
    /// Expected format: date,currentMiles,pricePerGallon,gallons,totalCost,isPartialFillUp,notes
    /// - Parameter content: CSV formatted string
    /// - Returns: Array of FuelingRecord
    static func importSimpleFormat(from content: String) -> [FuelingRecord] {
        var records: [FuelingRecord] = []

        let lines = content.components(separatedBy: .newlines)
        let dataLines = lines.dropFirst().filter { !$0.isEmpty }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for line in dataLines {
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }

            // Try to parse date in various formats
            var date: Date?
            if let d = dateFormatter.date(from: components[0]) {
                date = d
            } else if let d = ISO8601DateFormatter().date(from: components[0]) {
                date = d
            } else {
                // Try other common formats
                dateFormatter.dateFormat = "MM/dd/yyyy"
                if let d = dateFormatter.date(from: components[0]) {
                    date = d
                }
                dateFormatter.dateFormat = "yyyy-MM-dd" // Reset
            }

            guard let parsedDate = date,
                  let currentMiles = Double(components[1]),
                  let pricePerGallon = Double(components[2]),
                  let gallons = Double(components[3]),
                  let totalCost = Double(components[4]) else {
                continue
            }

            let isPartialFillUp = components.count > 5 ? components[5].lowercased() == "true" : false
            let notes = components.count > 6 && !components[6].isEmpty ? components[6] : nil

            let record = FuelingRecord(
                date: parsedDate,
                currentMiles: currentMiles,
                pricePerGallon: pricePerGallon,
                gallons: gallons,
                totalCost: totalCost,
                isPartialFillUp: isPartialFillUp,
                notes: notes
            )

            records.append(record)
        }

        return records
    }

    // MARK: - Helpers

    /// Parse a CSV line handling quoted fields
    /// - Parameter line: Single CSV line
    /// - Returns: Array of field values
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))

        return result
    }

    /// Validate CSV content before import
    /// - Parameter content: CSV formatted string
    /// - Returns: Tuple with validity and error message if invalid
    static func validateCSV(_ content: String) -> (isValid: Bool, error: String?) {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return (false, "The file is empty")
        }

        guard lines.count > 1 else {
            return (false, "The file only contains a header row with no data")
        }

        // Check if first line looks like a header
        let firstLine = lines[0].lowercased()
        let hasHeader = firstLine.contains("date") || firstLine.contains("miles") || firstLine.contains("gallon")

        if !hasHeader {
            return (false, "The file doesn't appear to have a valid header row")
        }

        return (true, nil)
    }

    /// Generate a sample CSV template
    /// - Returns: CSV formatted string with headers and example row
    static func generateTemplate() -> String {
        """
        date,currentMiles,pricePerGallon,gallons,totalCost,isPartialFillUp,notes
        2024-01-15,12500,3.459,10.5,36.32,false,"First fill-up of the year"
        2024-01-22,12800,3.399,11.2,38.07,false,""
        """
    }
}

