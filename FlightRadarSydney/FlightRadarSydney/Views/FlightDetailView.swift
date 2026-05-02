import SwiftUI
import MapKit

struct FlightDetailView: View {
    let aircraft: Aircraft
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if viewModel.isLoadingRoute {
                        ProgressView("Loading route info…")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let route = viewModel.selectedRoute {
                        routeSection(route)
                    }
                    positionSection
                    flightDataSection
                    identitySection
                }
                .padding()
            }
            .navigationTitle(aircraft.callsign)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(aircraft.isOnGround ? Color.gray.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: aircraft.isOnGround ? "airplane.arrival" : "airplane")
                    .font(.system(size: 32))
                    .foregroundStyle(aircraft.isOnGround ? .secondary : Color.blue)
            }
            Text(aircraft.callsign)
                .font(.title2.bold())
            if let op = aircraft.ownOp ?? viewModel.selectedRoute?.airline?.name {
                Text(op)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let r = aircraft.r {
                Text(r)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if aircraft.isOnGround {
                Label("On Ground", systemImage: "airplane.arrival")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func routeSection(_ route: FlightRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Route")
            HStack {
                airportCard(route.origin, label: "Origin")
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                airportCard(route.destination, label: "Destination")
            }
            if let airline = route.airline {
                infoRow("Airline", value: airline.name ?? "—")
                if let iata = airline.iata { infoRow("IATA", value: iata) }
                if let icao = airline.icao { infoRow("ICAO", value: icao) }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func airportCard(_ airport: Airport?, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let ap = airport {
                Text(ap.iataCode ?? ap.icaoCode ?? "—")
                    .font(.title2.bold())
                Text(ap.municipality ?? ap.name ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("—")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Position")
            if let lat = aircraft.lat, let lon = aircraft.lon {
                // Mini map
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let region = MKCoordinateRegion(center: coord,
                                                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
                Map(coordinateRegion: .constant(region), annotationItems: [aircraft]) { _ in
                    MapMarker(coordinate: coord, tint: .blue)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)

                infoRow("Latitude",  value: String(format: "%.5f°", lat))
                infoRow("Longitude", value: String(format: "%.5f°", lon))
            } else {
                Text("Position unknown").foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var flightDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Flight Data")
            infoRow("Altitude (Baro)",  value: aircraft.altitudeDisplay)
            if let geom = aircraft.altGeom {
                infoRow("Altitude (Geom)", value: "\(geom.formatted()) ft")
            }
            infoRow("Ground Speed", value: aircraft.speedDisplay)
            if let ias = aircraft.ias {
                infoRow("Indicated AS", value: String(format: "%.0f kts", ias))
            }
            if let tas = aircraft.tas {
                infoRow("True AS",       value: String(format: "%.0f kts", tas))
            }
            if let mach = aircraft.mach {
                infoRow("Mach",          value: String(format: "M%.3f", mach))
            }
            infoRow("Heading / Track",  value: aircraft.headingDisplay)
            if let squawk = aircraft.squawk {
                infoRow("Squawk",        value: squawk)
            }
            if let emerg = aircraft.emergency, emerg != "none" {
                infoRow("Emergency", value: emerg.uppercased())
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Aircraft Identity")
            infoRow("ICAO Hex",    value: aircraft.hex.uppercased())
            if let r = aircraft.r  { infoRow("Registration", value: r) }
            if let t = aircraft.t  { infoRow("Type Code",    value: t) }
            if let d = aircraft.desc { infoRow("Type",       value: d) }
            if let cat = aircraft.category { infoRow("Category", value: cat) }
            infoRow("Data Source", value: "adsb.lol (free ADS-B)")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

// Make Aircraft Identifiable for sheet binding
extension Aircraft: Hashable {
    static func == (lhs: Aircraft, rhs: Aircraft) -> Bool { lhs.hex == rhs.hex }
    func hash(into hasher: inout Hasher) { hasher.combine(hex) }
}
