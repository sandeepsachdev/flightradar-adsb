import SwiftUI
import MapKit
import UIKit

// MARK: - Map wrapper

struct FlightMapView: UIViewRepresentable {
    @ObservedObject var viewModel: FlightViewModel

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.setRegion(viewModel.defaultRegion, animated: false)
        map.showsUserLocation = true
        map.showsCompass = true
        map.showsScale = true
        map.register(AircraftAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: AircraftAnnotationView.reuseID)
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: "Airport")

        // Pin Sydney Airport
        let airport = MKPointAnnotation()
        airport.coordinate = CLLocationCoordinate2D(latitude: -33.9461, longitude: 151.1772)
        airport.title = "Sydney Airport (YSSY)"
        map.addAnnotation(airport)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let currentHexes = Set(
            map.annotations.compactMap { ($0 as? AircraftAnnotation)?.aircraft.hex }
        )
        let newHexes = Set(viewModel.aircraft.compactMap { $0.lat != nil ? $0.hex : nil })

        // Remove stale aircraft annotations
        let stale = map.annotations.filter {
            guard let a = $0 as? AircraftAnnotation else { return false }
            return !newHexes.contains(a.aircraft.hex)
        }
        if !stale.isEmpty { map.removeAnnotations(stale) }

        // Add or update
        for ac in viewModel.aircraft {
            guard let coord = ac.coordinate else { continue }
            if let existing = map.annotations
                .compactMap({ $0 as? AircraftAnnotation })
                .first(where: { $0.aircraft.hex == ac.hex }) {
                existing.coordinate = coord
                existing.aircraft = ac
                (map.view(for: existing) as? AircraftAnnotationView)?.configure(for: ac)
            } else {
                map.addAnnotation(AircraftAnnotation(aircraft: ac))
            }
        }

        // Highlight selected aircraft
        if let sel = viewModel.selectedAircraft,
           let ann = map.annotations
            .compactMap({ $0 as? AircraftAnnotation })
            .first(where: { $0.aircraft.hex == sel.hex }) {
            map.selectAnnotation(ann, animated: true)
        }

        _ = currentHexes // suppress warning
    }

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let viewModel: FlightViewModel
        init(viewModel: FlightViewModel) { self.viewModel = viewModel }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let ac = annotation as? AircraftAnnotation {
                let v = map.dequeueReusableAnnotationView(
                    withIdentifier: AircraftAnnotationView.reuseID,
                    for: ac) as! AircraftAnnotationView
                v.configure(for: ac.aircraft)
                return v
            }
            if annotation is MKPointAnnotation {
                let v = map.dequeueReusableAnnotationView(
                    withIdentifier: "Airport",
                    for: annotation) as! MKMarkerAnnotationView
                v.glyphImage = UIImage(systemName: "airplane.departure")
                v.markerTintColor = .systemOrange
                v.canShowCallout = true
                return v
            }
            return nil
        }

        func mapView(_ map: MKMapView, didSelect annotation: MKAnnotation) {
            guard let ac = annotation as? AircraftAnnotation else { return }
            viewModel.selectAircraft(ac.aircraft)
        }

        func mapView(_ map: MKMapView, didDeselect annotation: MKAnnotation) {
            guard annotation is AircraftAnnotation else { return }
            // Keep the sheet open; cleared when user dismisses detail
        }
    }
}

// MARK: - Annotation model

final class AircraftAnnotation: NSObject, MKAnnotation {
    var aircraft: Aircraft
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { aircraft.callsign }
    var subtitle: String? { aircraft.altitudeDisplay }

    init(aircraft: Aircraft) {
        self.aircraft = aircraft
        self.coordinate = aircraft.coordinate ?? CLLocationCoordinate2D()
    }
}

// MARK: - Annotation view

final class AircraftAnnotationView: MKAnnotationView {
    static let reuseID = "AircraftAnnotation"

    private let iconView = UIImageView()
    private let callsignLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = .zero
        canShowCallout = false

        iconView.frame = CGRect(x: 7, y: 7, width: 30, height: 30)
        iconView.contentMode = .center
        addSubview(iconView)

        callsignLabel.font = .systemFont(ofSize: 8, weight: .semibold)
        callsignLabel.textAlignment = .center
        callsignLabel.textColor = .white
        callsignLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
        callsignLabel.layer.cornerRadius = 4
        callsignLabel.layer.masksToBounds = true
        callsignLabel.frame = CGRect(x: -8, y: 44, width: 60, height: 14)
        addSubview(callsignLabel)
    }

    func configure(for aircraft: Aircraft) {
        let track = aircraft.track ?? 0
        let color: UIColor = aircraft.isOnGround ? .systemGray : .systemBlue
        iconView.image = Self.aircraftIcon(track: track, color: color)
        callsignLabel.text = aircraft.callsign
        callsignLabel.backgroundColor = aircraft.isOnGround
            ? UIColor.systemGray.withAlphaComponent(0.85)
            : UIColor.systemBlue.withAlphaComponent(0.85)
    }

    private static func aircraftIcon(track: Double, color: UIColor) -> UIImage {
        let size = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: size.width / 2, y: size.height / 2)
            // track is degrees clockwise from north; CGAffineTransform rotation is CCW in standard coords
            // but UIKit Y-axis is flipped, so clockwise radians = track * pi/180
            c.rotate(by: CGFloat(track) * .pi / 180)

            color.setFill()
            UIColor.white.withAlphaComponent(0.9).setStroke()

            // More realistic aircraft silhouette pointing "up" (north before rotation)
            let path = UIBezierPath()
            
            // Nose
            path.move(to: CGPoint(x: 0, y: -12))
            
            // Right side of fuselage to wing
            path.addLine(to: CGPoint(x: 1.5, y: -8))
            path.addLine(to: CGPoint(x: 1.5, y: -2))
            
            // Right wing
            path.addLine(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: 10, y: 2))
            path.addLine(to: CGPoint(x: 2, y: 1))
            
            // Right side fuselage to tail
            path.addLine(to: CGPoint(x: 2, y: 8))
            
            // Right horizontal stabilizer
            path.addLine(to: CGPoint(x: 4.5, y: 9))
            path.addLine(to: CGPoint(x: 4.5, y: 10))
            path.addLine(to: CGPoint(x: 1.5, y: 9.5))
            
            // Vertical stabilizer (tail fin)
            path.addLine(to: CGPoint(x: 1, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 13))
            path.addLine(to: CGPoint(x: -1, y: 12))
            path.addLine(to: CGPoint(x: -1.5, y: 9.5))
            
            // Left horizontal stabilizer
            path.addLine(to: CGPoint(x: -4.5, y: 10))
            path.addLine(to: CGPoint(x: -4.5, y: 9))
            path.addLine(to: CGPoint(x: -2, y: 8))
            
            // Left side fuselage
            path.addLine(to: CGPoint(x: -2, y: 1))
            
            // Left wing
            path.addLine(to: CGPoint(x: -10, y: 2))
            path.addLine(to: CGPoint(x: -10, y: 0))
            path.addLine(to: CGPoint(x: -1.5, y: -2))
            
            // Left side of fuselage
            path.addLine(to: CGPoint(x: -1.5, y: -8))
            
            path.close()
            path.lineWidth = 1.0
            path.fill()
            path.stroke()
        }
    }
}
