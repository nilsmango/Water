//
//  SpeedGradientMapCoordinator.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import MapKit

extension SpeedGradientMapView {

    final class Coordinator: NSObject, MKMapViewDelegate {

        var locations: [LocationData] = []

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
            renderer.lineWidth = 4
            renderer.lineCap = .round

            let (colors, stops) = makeGradientStops(from: locations)

            debugMap("Gradient stops count: \(stops.count)")
            debugMap("First stop: \(stops.first ?? -1), last stop: \(stops.last ?? -1)")

            renderer.setColors(colors, locations: stops)
            debugMap("Gradient renderer configured")

            return renderer
        }
    }
}
