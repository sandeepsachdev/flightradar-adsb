import Foundation
import CoreLocation

struct ADSBResponse: Codable {
    let ac: [Aircraft]
    let now: Double?
    let total: Int?
}

// alt_baro can be an Int (feet) or the string "ground"
enum AltitudeBaro: Codable {
    case feet(Int)
    case ground

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) {
            self = .feet(v)
        } else {
            self = .ground
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .feet(let v): try c.encode(v)
        case .ground:      try c.encode("ground")
        }
    }

    var displayString: String {
        switch self {
        case .feet(let v): return "\(v.formatted()) ft"
        case .ground:      return "On Ground"
        }
    }

    var feetValue: Int {
        switch self {
        case .feet(let v): return v
        case .ground:      return 0
        }
    }

    var isGround: Bool {
        if case .ground = self { return true }
        return false
    }
}

struct Aircraft: Codable, Identifiable {
    var id: String { hex }

    // Core identity
    let hex: String
    let type: String?
    let flight: String?     // ATC callsign
    let r: String?          // registration
    let t: String?          // ICAO type code (e.g. "B738")
    let desc: String?       // human-readable type description

    // Position
    let lat: Double?
    let lon: Double?

    // Altitude
    let altBaro: AltitudeBaro?
    let altGeom: Int?

    // Speed & direction
    let gs: Double?         // ground speed (knots)
    let ias: Double?        // indicated airspeed (knots)
    let tas: Double?        // true airspeed (knots)
    let mach: Double?
    let track: Double?      // true track over ground, degrees

    // Other
    let seen: Double?
    let seenPos: Double?
    let squawk: String?
    let emergency: String?
    let navAltitudeMcp: Int?
    let ownOp: String?      // operator / airline name
    let dbFlags: Int?
    let category: String?   // wake turbulence category

    enum CodingKeys: String, CodingKey {
        case hex, type, flight, r, t, desc, lat, lon
        case altBaro = "alt_baro"
        case altGeom = "alt_geom"
        case gs, ias, tas, mach, track, seen
        case seenPos = "seen_pos"
        case squawk, emergency
        case navAltitudeMcp = "nav_altitude_mcp"
        case ownOp, dbFlags, category
    }

    // MARK: - Convenience

    var callsign: String {
        flight?.trimmingCharacters(in: .whitespaces).nonEmpty ?? hex.uppercased()
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var altitudeDisplay: String { altBaro?.displayString ?? "—" }

    var speedDisplay: String {
        guard let gs else { return "—" }
        return String(format: "%.0f kts", gs)
    }

    var headingDisplay: String {
        guard let track else { return "—" }
        return String(format: "%.0f°", track)
    }

    var isOnGround: Bool { altBaro?.isGround ?? false }

    func distance(from coord: CLLocationCoordinate2D) -> CLLocationDistance {
        guard let c = coordinate else { return .greatestFiniteMagnitude }
        return CLLocation(latitude: c.latitude, longitude: c.longitude)
            .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
