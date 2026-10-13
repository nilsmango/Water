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

        context.coordinator.mapViewRef = mapView
        context.coordinator.fullLocationData = locations
        context.coordinator.polylineData.removeAll()

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard locations.count > 1 else {
            debugMap("Not enough locations to draw a route")
            return
        }

        context.coordinator.lineWidth = lineWidth

        let routeSegments = splitGPSLocationSegments(from: locations)
        let allGradientLocations = routeSegments.flatMap {
            downsampleLocations($0, targetCount: MAX_GRADIENT_STOPS)
        }
        context.coordinator.locations = allGradientLocations
        var routeBounds = MKMapRect.null
        var firstCoordinate: CLLocationCoordinate2D?
        var lastCoordinate: CLLocationCoordinate2D?

        for routeSegment in routeSegments {
            let downsampledForPolyline = downsamplePolylineCoordinates(routeSegment, targetCount: MAX_POLYLINE_POINTS)
            let downsampledForGradient = downsampleLocations(routeSegment, targetCount: MAX_GRADIENT_STOPS)
            let coordinates = makeSmoothedCoordinates(from: downsampledForPolyline)
            guard coordinates.count > 1 else { continue }

            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.polylineData[polyline] = SpeedGradientMapView.Coordinator.PolylineInfo(
                gradientLocations: downsampledForGradient,
                maxSpeed: maxSpeed(in: downsampledForGradient)
            )
            routeBounds = MKMapRectUnion(routeBounds, polyline.boundingMapRect)
            firstCoordinate = firstCoordinate ?? coordinates.first
            lastCoordinate = coordinates.last

            debugMap("Polyline pointCount: \(polyline.pointCount)")
            debugMap("Polyline boundingRect: \(polyline.boundingMapRect)")
            mapView.addOverlay(polyline)
        }
        guard let firstCoordinate, let lastCoordinate, !MKMapRectIsNull(routeBounds) else { return }
        debugMap("Overlay segments added")

        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = firstCoordinate
        startAnnotation.title = "Start"
        mapView.addAnnotation(startAnnotation)

        let finishAnnotation = MKPointAnnotation()
        finishAnnotation.coordinate = lastCoordinate
        finishAnnotation.title = "Finish"
        mapView.addAnnotation(finishAnnotation)

        mapView.setVisibleMapRect(
            routeBounds,
            edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40),
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
