import SwiftUI
import SwiftData

struct VehicleListView: View {
    let vehicles: [Vehicle]
    @Binding var selectedVehicle: Vehicle?
    @Binding var showingAddVehicle: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteAlert = false
    @State private var vehicleToDelete: Vehicle?
    @State private var showingSettings = false

    var body: some View {
        List {
            ForEach(vehicles) { vehicle in
                NavigationLink(value: vehicle) {
                    VehicleRowView(vehicle: vehicle)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vehicleToDelete = vehicle
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Vehicles")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddVehicle = true }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Delete Vehicle", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                vehicleToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let vehicle = vehicleToDelete {
                    deleteVehicle(vehicle)
                }
            }
        } message: {
            Text("Are you sure you want to delete this vehicle and all its fueling records? This action cannot be undone.")
        }
    }

    private func deleteVehicle(_ vehicle: Vehicle) {
        withAnimation {
            modelContext.delete(vehicle)
            vehicleToDelete = nil
        }
    }
}

struct VehicleRowView: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal.opacity(0.7), .cyan.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.custom("Avenir Next", size: 17))
                    .fontWeight(.semibold)

                if let lastRecord = vehicle.lastRecord {
                    Text("Last fill: \(lastRecord.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("No records yet")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let recordCount = vehicle.fuelingRecords?.count, recordCount > 0 {
                Text("\(recordCount)")
                    .font(.custom("Avenir Next", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }
}

/// Wrapper to make PrefilledFuelData identifiable for sheet presentation
struct AddRecordSheetData: Identifiable {
    let id = UUID()
    let prefilledData: PrefilledFuelData?
}

struct VehicleDetailView: View {
    let vehicle: Vehicle

    @Environment(\.modelContext) private var modelContext
    @State private var addRecordSheetData: AddRecordSheetData?
    @State private var showingAIScanner = false
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var showingSummary = false
    @State private var lastAddedRecord: FuelingRecord?

    var body: some View {
        TabView {
            DashboardView(vehicle: vehicle)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
                }

            HistoryView(vehicle: vehicle)
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle")
                }
        }
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingExportOptions = true }) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(vehicle.fuelingRecords?.isEmpty ?? true)

                    Button(action: { showingImportPicker = true }) {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { addRecordSheetData = AddRecordSheetData(prefilledData: nil) }) {
                        Label("Manual Input", systemImage: "square.and.pencil")
                    }

                    Button(action: { showingAIScanner = true }) {
                        Label("AI Scan Receipt", systemImage: "camera.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .sheet(item: $addRecordSheetData) { sheetData in
            AddRecordView(vehicle: vehicle, prefilledData: sheetData.prefilledData) { record in
                lastAddedRecord = record
                showingSummary = true
            }
        }
        .sheet(isPresented: $showingAIScanner) {
            AIReceiptScannerView(vehicle: vehicle) { data in
                // Small delay to allow scanner sheet to dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    addRecordSheetData = AddRecordSheetData(prefilledData: data)
                }
            }
        }
        .sheet(isPresented: $showingSummary) {
            if let record = lastAddedRecord {
                FuelingSummaryPopup(record: record)
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportCSVView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingImportPicker) {
            ImportCSVView(vehicle: vehicle)
        }
    }
}

#Preview {
    NavigationStack {
        VehicleListView(
            vehicles: [],
            selectedVehicle: .constant(nil),
            showingAddVehicle: .constant(false)
        )
    }
    .modelContainer(for: [Vehicle.self, FuelingRecord.self], inMemory: true)
}

