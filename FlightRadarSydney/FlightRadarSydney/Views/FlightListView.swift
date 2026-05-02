import SwiftUI

struct FlightListView: View {
    @ObservedObject var viewModel: FlightViewModel
    @State private var sortOrder: SortOrder = .altitude

    enum SortOrder: String, CaseIterable {
        case altitude = "Altitude"
        case speed    = "Speed"
        case callsign = "Callsign"
    }

    private var sortedAircraft: [Aircraft] {
        let base = viewModel.filteredAircraft
        switch sortOrder {
        case .altitude: return base.sorted { ($0.altBaro?.feetValue ?? 0) > ($1.altBaro?.feetValue ?? 0) }
        case .speed:    return base.sorted { ($0.gs ?? 0) > ($1.gs ?? 0) }
        case .callsign: return base.sorted { $0.callsign < $1.callsign }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statsBar
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)

                if sortedAircraft.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    List(sortedAircraft) { ac in
                        AircraftRow(aircraft: ac)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.selectAircraft(ac) }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.fetch() }
                }
            }
            .navigationTitle("Flights near Sydney")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search callsign, type, airline…")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button { Task { await viewModel.fetch() } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(item: $viewModel.selectedAircraft) { ac in
                FlightDetailView(aircraft: ac, viewModel: viewModel)
            }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 20) {
            Label("\(viewModel.airborneCount) airborne", systemImage: "airplane.departure")
            Label("\(viewModel.groundCount) on ground", systemImage: "airplane.arrival")
            Spacer()
            if let ts = viewModel.lastUpdated {
                Text(ts, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var emptyState: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "No Aircraft Found",
                    systemImage: "airplane.circle",
                    description: Text("Pull to refresh or check your internet connection.")
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No Aircraft Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Pull to refresh or check your internet connection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

// MARK: - Plane Icon View

struct PlaneIconView: View {
    let isOnGround: Bool
    let heading: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isOnGround ? Color.secondary.opacity(0.15) : Color.blue.opacity(0.12))
            
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                // Rotate based on heading
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: Angle(degrees: heading))
                context.translateBy(x: -center.x, y: -center.y)
                
                // Scale factor for icon size
                let scale: CGFloat = 1.2
                let cx = center.x
                let cy = center.y
                
                // Draw airplane silhouette (pointing up/north)
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy - 10 * scale))              // nose
                path.addLine(to: CGPoint(x: cx + 7 * scale, y: cy + 2 * scale))  // right wing tip
                path.addLine(to: CGPoint(x: cx + 1.5 * scale, y: cy + 0.5 * scale)) // right wing root
                path.addLine(to: CGPoint(x: cx + 2.5 * scale, y: cy + 9 * scale))  // right tail
                path.addLine(to: CGPoint(x: cx, y: cy + 7.5 * scale))          // tail center
                path.addLine(to: CGPoint(x: cx - 2.5 * scale, y: cy + 9 * scale))  // left tail
                path.addLine(to: CGPoint(x: cx - 1.5 * scale, y: cy + 0.5 * scale)) // left wing root
                path.addLine(to: CGPoint(x: cx - 7 * scale, y: cy + 2 * scale))  // left wing tip
                path.closeSubpath()
                
                // Fill and stroke
                context.fill(path, with: .color(isOnGround ? .secondary : .blue))
                context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Row

struct AircraftRow: View {
    let aircraft: Aircraft

    var body: some View {
        HStack(spacing: 12) {
            // Airplane Icon
            PlaneIconView(
                isOnGround: aircraft.isOnGround,
                heading: aircraft.track ?? 0
            )
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(aircraft.callsign)
                        .font(.headline)
                    if let op = aircraft.ownOp {
                        Text("·")
                        Text(op)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 14) {
                    if let t = aircraft.t {
                        tag(t, icon: "airplane.circle")
                    }
                    tag(aircraft.altitudeDisplay, icon: "arrow.up")
                    tag(aircraft.speedDisplay, icon: "speedometer")
                }
            }

            Spacer()

            if let r = aircraft.r {
                Text(r)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func tag(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
