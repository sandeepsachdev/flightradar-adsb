import Foundation

// Fetches route and airline info from api.adsbdb.com (free, no API key required)
// Docs: https://www.adsbdb.com
final class RouteService {
    static let shared = RouteService()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg)
    }()

    private var cache: [String: FlightRoute] = [:]

    func fetchRoute(callsign: String) async throws -> FlightRoute? {
        let key = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        if let cached = cache[key] { return cached }

        guard !key.isEmpty,
              let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(key)") else {
            return nil
        }

        var req = URLRequest(url: url)
        req.setValue("FlightRadarSydney/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        let decoded = try JSONDecoder().decode(RouteResponse.self, from: data)
        let route = decoded.response?.flightroute
        if let route { cache[key] = route }
        return route
    }
}
