import Foundation
import MapKit
import Combine

@MainActor
final class FlightViewModel: ObservableObject {

    // MARK: - Published state

    @Published var aircraft: [Aircraft] = []
    @Published var selectedAircraft: Aircraft?
    @Published var selectedRoute: FlightRoute?
    @Published var isLoading = false
    @Published var isLoadingRoute = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var searchText = ""

    // MARK: - Configuration

    // Sydney Airport
    let centerCoordinate = CLLocationCoordinate2D(latitude: -33.9461, longitude: 151.1772)
    let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.9461, longitude: 151.1772),
        span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
    )
    let refreshInterval: TimeInterval = 10

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    var filteredAircraft: [Aircraft] {
        guard !searchText.isEmpty else { return aircraft }
        let q = searchText.lowercased()
        return aircraft.filter {
            $0.callsign.lowercased().contains(q) ||
            ($0.t?.lowercased().contains(q) ?? false) ||
            ($0.r?.lowercased().contains(q) ?? false) ||
            ($0.ownOp?.lowercased().contains(q) ?? false)
        }
    }

    var airborneCount: Int { aircraft.filter { !$0.isOnGround }.count }
    var groundCount: Int  { aircraft.filter { $0.isOnGround }.count }

    // MARK: - Lifecycle

    func startRefreshing() {
        stopRefreshing()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetch()
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Data fetching

    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await ADSBService.shared.fetchAircraft(
                lat: centerCoordinate.latitude,
                lon: centerCoordinate.longitude,
                radiusNM: 150
            )
            // Sort: airborne first by altitude desc, then ground aircraft
            aircraft = fetched.sorted {
                let a0 = $0.altBaro?.feetValue ?? 0
                let a1 = $1.altBaro?.feetValue ?? 0
                return a0 > a1
            }
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private var routeFetchTask: Task<Void, Never>?
    
    func selectAircraft(_ ac: Aircraft?) {
        // Cancel any pending route fetch
        routeFetchTask?.cancel()
        
        selectedAircraft = ac
        selectedRoute = nil
        
        guard let ac else { return }
        
        // Fetch route asynchronously without blocking UI
        routeFetchTask = Task { @MainActor in
            await fetchRoute(for: ac)
        }
    }

    private func fetchRoute(for ac: Aircraft) async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }
        
        do {
            selectedRoute = try await RouteService.shared.fetchRoute(callsign: ac.callsign)
        } catch {
            // Route info is best-effort; ignore errors
        }
    }
}
