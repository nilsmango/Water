//
//  SpeedGradientMapCoordinator.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import MapKit
import UIKit

class CircleAnnotationView: MKAnnotationView {

    enum MarkerType {
        case start
        case finish
    }

    private let markerType: MarkerType

    init(annotation: MKAnnotation?, reuseIdentifier: String?, markerType: MarkerType) {
        self.markerType = markerType
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        self.markerType = .start
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        canShowCallout = false

        let width = 18.0
        let circle = UIView(frame: CGRect(x: 0, y: 0, width: width, height: width))
        circle.layer.cornerRadius = width / 2
        circle.layer.borderWidth = 2
        circle.layer.borderColor = UIColor.white.cgColor
        circle.backgroundColor = markerType == .start ? .green : .red
        circle.isUserInteractionEnabled = false

        addSubview(circle)

        bounds = CGRect(x: 0, y: 0, width: width, height: width)
        centerOffset = CGPoint(x: 0, y: -width / 2)
    }
}

extension SpeedGradientMapView {

    final class Coordinator: NSObject, MKMapViewDelegate {

        var locations: [LocationData] = []
        var lineWidth: CGFloat = 9.0

        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer {

            debugMap("rendererFor overlay called")

            guard
                let polyline = overlay as? MKPolyline,
                locations.count > 1
            else {
                debugMap("Overlay is not MKPolyline or locations missing")
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKGradientPolylineRenderer(polyline: polyline)
            renderer.lineWidth = lineWidth
            renderer.lineCap = .round

            let (colors, stops) = makeGradientStops(from: locations)

            debugMap("Gradient stops count: \(stops.count)")
            debugMap("First stop: \(stops.first ?? -1), last stop: \(stops.last ?? -1)")

            renderer.setColors(colors, locations: stops)
            debugMap("Gradient renderer configured")

            return renderer
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {

            guard let title = annotation.title else { return nil }

            guard title == "Start" || title == "Finish" else { return nil }

            let identifier = title ?? "Something went wrong"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                let type: CircleAnnotationView.MarkerType =
                    title == "Start" ? .start : .finish

                annotationView = CircleAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier,
                    markerType: type
                )
            } else {
                annotationView?.annotation = annotation
            }

            return annotationView
        }
    }
}
