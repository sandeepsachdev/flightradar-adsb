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
            // Route and Airline
            VStack(spacing: 6) {
                if viewModel.isLoadingRoute {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading route…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let route = viewModel.selectedRoute {
                    // Route info — city names primary, codes secondary
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(route.origin?.municipality ?? route.origin?.name ?? "—")
                                .font(.title3.bold())
                                .multilineTextAlignment(.trailing)
                            if let code = route.origin?.iataCode ?? route.origin?.icaoCode {
                                Text(code)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Image(systemName: "arrow.right")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.destination?.municipality ?? route.destination?.name ?? "—")
                                .font(.title3.bold())
                                .multilineTextAlignment(.leading)
                            if let code = route.destination?.iataCode ?? route.destination?.icaoCode {
                                Text(code)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let airline = route.airline?.name {
                        Text(airline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Departure time if available
                    if let depTime = route.departureTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("Departed: \(depTime)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No route information")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
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
