//
//  SpeedGradientMapView.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import SwiftUI
import MapKit

struct SpeedGradientMapView: UIViewRepresentable {

    let locations: [LocationData]
    var lineWidth = 2.0

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        debugMap("updateUIView called with \(locations.count) locations")

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard locations.count > 1 else {
            debugMap("Not enough locations to draw a route")
            return
        }

        context.coordinator.lineWidth = lineWidth
        context.coordinator.locations = locations

        let coordinates = makeSmoothedCoordinates(from: locations)

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

        debugMap("Polyline pointCount: \(polyline.pointCount)")
        debugMap("Polyline boundingRect: \(polyline.boundingMapRect)")

        mapView.addOverlay(polyline)
        debugMap("Overlay added")

        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = coordinates.first!
        startAnnotation.title = "Start"
        mapView.addAnnotation(startAnnotation)

        let finishAnnotation = MKPointAnnotation()
        finishAnnotation.coordinate = coordinates.last!
        finishAnnotation.title = "Finish"
        mapView.addAnnotation(finishAnnotation)

        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40),
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
