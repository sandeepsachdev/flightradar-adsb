import SwiftUI
import MapKit

struct FlightDetailView: View {
    let aircraft: Aircraft
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                compactCard
                Spacer()
            }
            .padding()
            .navigationTitle(aircraft.callsign)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Compact Card

    private var compactCard: some View {
        VStack(spacing: 16) {
            // Callsign and Route
            VStack(spacing: 6) {
                Text(aircraft.callsign)
                    .font(.title.bold())
                
                if viewModel.isLoadingRoute {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading route…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let route = viewModel.selectedRoute {
                    // Route info
                    HStack(spacing: 8) {
                        if let origin = route.origin?.iataCode ?? route.origin?.icaoCode {
                            Text(origin)
                                .font(.headline)
                        }
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let dest = route.destination?.iataCode ?? route.destination?.icaoCode {
                            Text(dest)
                                .font(.headline)
                        }
                    }
                    
                    if let airline = route.airline?.name {
                        Text(airline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            
            Divider()
            
            // Flight data in two columns
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    dataItem(label: "Altitude", value: aircraft.altitudeDisplay, icon: "arrow.up")
                    dataItem(label: "Speed", value: aircraft.speedDisplay, icon: "speedometer")
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 10) {
                    if let reg = aircraft.r {
                        dataItem(label: "Registration", value: reg, icon: "airplane.circle")
                    }
                    if let type = aircraft.t {
                        dataItem(label: "Type", value: type, icon: "airplane")
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func dataItem(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
    }
}

// Make Aircraft Identifiable for sheet binding
extension Aircraft: Hashable {
    static func == (lhs: Aircraft, rhs: Aircraft) -> Bool { lhs.hex == rhs.hex }
    func hash(into hasher: inout Hasher) { hasher.combine(hex) }
}
