import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            mapTab
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(0)

            FlightListView(viewModel: viewModel)
                .tabItem { Label("Flights", systemImage: "airplane") }
                .tag(1)
        }
        .task { viewModel.startRefreshing() }
        .onDisappear { viewModel.stopRefreshing() }
    }

    private var mapTab: some View {
        ZStack(alignment: .top) {
            FlightMapView(viewModel: viewModel)
                .ignoresSafeArea()

            // Status overlay
            statusOverlay
                .padding(.horizontal)
                .padding(.top, 8)
        }
        .sheet(item: $viewModel.selectedAircraft) { ac in
            FlightDetailView(aircraft: ac, viewModel: viewModel)
        }
        .navigationTitle("Map")
    }

    private var statusOverlay: some View {
        HStack(spacing: 10) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.airborneCount) airborne · \(viewModel.groundCount) on ground")
                    .font(.caption.bold())
                if let ts = viewModel.lastUpdated {
                    Text("Updated \(ts, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let err = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(err)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
