import Foundation

// Fetches live aircraft positions from adsb.lol (free, no API key required)
// Docs: https://api.adsb.lol/docs
final class ADSBService {
    static let shared = ADSBService()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    /// Returns aircraft within `radiusNM` nautical miles of the given coordinate.
    func fetchAircraft(lat: Double, lon: Double, radiusNM: Int = 100) async throws -> [Aircraft] {
        let urlStr = "https://api.adsb.lol/v2/lat/\(lat)/lon/\(lon)/dist/\(radiusNM)"
        guard let url = URL(string: urlStr) else { throw ADSBError.badURL }

        var req = URLRequest(url: url)
        req.setValue("FlightRadarSydney/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw ADSBError.badResponse
        }

        let decoded = try JSONDecoder().decode(ADSBResponse.self, from: data)
        // Only return aircraft that have a known position
        return decoded.ac.filter { $0.lat != nil && $0.lon != nil }
    }
}

enum ADSBError: LocalizedError {
    case badURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badURL:      return "Invalid API URL"
        case .badResponse: return "Server returned an error response"
        }
    }
}
