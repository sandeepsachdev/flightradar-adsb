import Foundation

// Response from api.adsbdb.com/v0/callsign/{callsign}
struct RouteResponse: Codable {
    let response: RoutePayload?
}

struct RoutePayload: Codable {
    let flightroute: FlightRoute?
}

struct FlightRoute: Codable {
    let callsign: String?
    let callsignIcao: String?
    let callsignIata: String?
    let origin: Airport?
    let destination: Airport?
    let airline: Airline?
    
    // Schedule information (if available from API)
    let scheduledDeparture: String?
    let actualDeparture: String?
    let estimatedArrival: String?

    enum CodingKeys: String, CodingKey {
        case callsign
        case callsignIcao = "callsign_icao"
        case callsignIata = "callsign_iata"
        case origin, destination, airline
        case scheduledDeparture = "scheduled_departure"
        case actualDeparture = "actual_departure"
        case estimatedArrival = "estimated_arrival"
    }
    
    var departureTime: String? {
        actualDeparture ?? scheduledDeparture
    }
}

struct Airport: Codable {
    let name: String?
    let iataCode: String?
    let icaoCode: String?
    let municipality: String?
    let countryName: String?
    let latitude: Double?
    let longitude: Double?
    let elevation: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case iataCode = "iata_code"
        case icaoCode = "icao_code"
        case municipality
        case countryName = "country_name"
        case latitude, longitude, elevation
    }

    var displayName: String {
        let city = municipality ?? ""
        let code = iataCode ?? icaoCode ?? ""
        if city.isEmpty { return code }
        if code.isEmpty { return city }
        return "\(city) (\(code))"
    }
}

struct Airline: Codable {
    let name: String?
    let iata: String?
    let icao: String?
    let country: String?
    let callsign: String?
}
