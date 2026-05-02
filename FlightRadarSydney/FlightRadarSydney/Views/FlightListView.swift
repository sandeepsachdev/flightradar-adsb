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
            Label("\(viewModel.airborneCount) airborne", systemImage: "airplane")
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
        ContentUnavailableView(
            "No Aircraft Found",
            systemImage: "airplane.circle",
            description: Text("Pull to refresh or check your internet connection.")
        )
    }
}

// MARK: - Row

struct AircraftRow: View {
    let aircraft: Aircraft

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(aircraft.isOnGround ? Color.secondary.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: aircraft.isOnGround ? "airplane.arrival" : "airplane")
                    .font(.system(size: 18))
                    .foregroundStyle(aircraft.isOnGround ? .secondary : .blue)
                    .rotationEffect(.degrees(aircraft.track ?? 0))
            }

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
