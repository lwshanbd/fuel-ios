import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var selectedVehicle: Vehicle?
    @State private var showingAddVehicle = false
    @State private var showingSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var hasPerformedInitialNavigation = false

    // Store the last viewed vehicle ID
    @AppStorage("lastViewedVehicleID") private var lastViewedVehicleID: String = ""

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if vehicles.isEmpty {
                    EmptyVehicleView(
                        showingAddVehicle: $showingAddVehicle,
                        showingSettings: $showingSettings
                    )
                } else {
                    VehicleListView(
                        vehicles: vehicles,
                        selectedVehicle: $selectedVehicle,
                        showingAddVehicle: $showingAddVehicle
                    )
                }
            }
            .navigationDestination(for: Vehicle.self) { vehicle in
                VehicleDetailView(vehicle: vehicle)
                    .onAppear {
                        // Save this vehicle as the last viewed
                        lastViewedVehicleID = vehicle.id.uuidString
                    }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                navigateToLastVehicleIfNeeded()
            }
            .onChange(of: vehicles) { oldVehicles, newVehicles in
                // If a new vehicle was added and we were empty before, navigate to it
                if oldVehicles.isEmpty && !newVehicles.isEmpty {
                    if let first = newVehicles.first {
                        navigationPath.append(first)
                        hasPerformedInitialNavigation = true
                    }
                }
            }
        }
    }

    private func navigateToLastVehicleIfNeeded() {
        // Only auto-navigate once on initial app launch
        guard !hasPerformedInitialNavigation else { return }
        guard !vehicles.isEmpty else { return }

        hasPerformedInitialNavigation = true

        // Try to find the last viewed vehicle
        if !lastViewedVehicleID.isEmpty,
           let lastID = UUID(uuidString: lastViewedVehicleID),
           let lastVehicle = vehicles.first(where: { $0.id == lastID }) {
            navigationPath.append(lastVehicle)
        } else if let firstVehicle = vehicles.first {
            // Fallback to the first vehicle if no last viewed or it no longer exists
            navigationPath.append(firstVehicle)
        }
    }
}

struct EmptyVehicleView: View {
    @Binding var showingAddVehicle: Bool
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "car.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Welcome to Fuel")
                .font(.custom("Avenir Next", size: 32))
                .fontWeight(.bold)

            Text("Track your fuel consumption, costs, and efficiency.")
                .font(.custom("Avenir Next", size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingAddVehicle = true }) {
                Label("Add Your First Vehicle", systemImage: "plus.circle.fill")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Vehicle.self, FuelingRecord.self], inMemory: true)
}

