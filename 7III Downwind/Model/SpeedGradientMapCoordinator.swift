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
    
    private var markerColor: UIColor {
        switch markerType {
        case .start:
            // Darker green (roughly 2× darker than system green)
            return UIColor(
                red: 90/255,
                green: 190/255,
                blue: 90/255,
                alpha: 1.0
            )

        case .finish:
            // Slightly lighter red
            return UIColor(
                red: 0.95,
                green: 0.30,
                blue: 0.30,
                alpha: 1.0
            )
        }
    }

    private let markerType: MarkerType
    private let circleSize: CGFloat = 18

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

        // --- Circle ---
        let circle = UIView(frame: CGRect(x: 0, y: 0, width: circleSize, height: circleSize))
        circle.layer.cornerRadius = circleSize / 2
        circle.layer.borderWidth = 2
        circle.layer.borderColor = UIColor.white.cgColor
        circle.backgroundColor = markerColor
        circle.isUserInteractionEnabled = false

        addSubview(circle)

        if let title = annotation?.title ?? nil {
            let label = HaloLabel()
            label.text = title
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textColor = .black
            label.haloColor = .white
            label.haloWidth = 2
            label.textAlignment = .center
            label.backgroundColor = .clear
            label.numberOfLines = 1
            label.isUserInteractionEnabled = false

            label.sizeToFit()

                    // Center under the circle without affecting anchor
                    label.frame.origin = CGPoint(
                        x: (circleSize - label.bounds.width) / 2,
                        y: circleSize + 6
                    )

                    addSubview(label)
                }

        // IMPORTANT: keep bounds & offset tied to the circle only
        bounds = CGRect(x: 0, y: 0, width: circleSize, height: circleSize)
        centerOffset = CGPoint(x: 0, y: -circleSize / 2)
    }
}

final class HaloLabel: UILabel {

    var haloColor: UIColor = .white
    var haloWidth: CGFloat = 1.5
    override func drawText(in rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            super.drawText(in: rect)
            return
        }

        ctx.saveGState()

        // Draw halo
        ctx.setLineWidth(haloWidth)
        ctx.setLineJoin(.round)
        ctx.setTextDrawingMode(.stroke)
        let originalColor = textColor
        textColor = haloColor
        super.drawText(in: rect)

        // Draw text
        ctx.setTextDrawingMode(.fill)
        textColor = originalColor
        super.drawText(in: rect)

        ctx.restoreGState()
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
