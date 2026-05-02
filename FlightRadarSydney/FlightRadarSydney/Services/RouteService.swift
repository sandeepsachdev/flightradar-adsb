import Foundation

// Fetches route and airline info from api.adsbdb.com (free, no API key required)
// Docs: https://www.adsbdb.com
final class RouteService {
    static let shared = RouteService()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8  // Reduced timeout for faster failure
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()

    private var cache: [String: CachedRoute] = [:]
    private let cacheExpirationSeconds: TimeInterval = 3600 // 1 hour
    
    private struct CachedRoute {
        let route: FlightRoute?
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 3600
        }
    }

    func fetchRoute(callsign: String) async throws -> FlightRoute? {
        let key = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        
        // Check cache first
        if let cached = cache[key], !cached.isExpired {
            return cached.route
        }

        guard !key.isEmpty,
              let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(key)") else {
            return nil
        }

        var req = URLRequest(url: url)
        req.setValue("FlightRadarSydney/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .returnCacheDataElseLoad

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        let decoded = try JSONDecoder().decode(RouteResponse.self, from: data)
        let route = decoded.response?.flightroute
        
        // Cache the result
        cache[key] = CachedRoute(route: route, timestamp: Date())
        
        return route
    }
}