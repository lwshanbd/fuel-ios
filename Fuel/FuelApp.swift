import SwiftUI
import SwiftData

@main
struct FuelApp: App {
    @State private var importedFileURL: URL?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            FuelingRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(importedFileURL: $importedFileURL)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        // Check if it's a CSV file
        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "csv" else {
            return
        }

        // Need to start accessing security-scoped resource for files from other apps
        let accessing = url.startAccessingSecurityScopedResource()

        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy the file to a temporary location to ensure we can access it
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)

            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            try FileManager.default.copyItem(at: url, to: tempURL)

            // Set the URL - this will trigger the sheet in ContentView
            importedFileURL = tempURL
        } catch {
            print("Failed to copy file: \(error.localizedDescription)")
        }
    }
}

