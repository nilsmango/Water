//
//  SpeedGradientStatisticsMap.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import SwiftUI
import MapKit

struct SpeedGradientStatisticsMap: UIViewRepresentable {

    @Binding var statisticsData: RunStatistic

    var lineWidth = 2.0
    let waveOpacity: CGFloat = 1.0
    let nonWaveOpacity: CGFloat = 0.3

    var maxPolylinePoints: Int = MAX_POLYLINE_POINTS
    var maxGradientStops: Int = MAX_GRADIENT_STOPS
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        let currentHash = statisticsData.id.hashValue

        if context.coordinator.dataHash == currentHash {
            return
        }

        context.coordinator.dataHash = currentHash
        context.coordinator.mapViewRef = mapView
        context.coordinator.currentLineWidth = lineWidth
        context.coordinator.currentWaveOpacity = waveOpacity
        context.coordinator.currentNonWaveOpacity = nonWaveOpacity
        context.coordinator.currentMaxPolylinePoints = maxPolylinePoints
        context.coordinator.currentMaxGradientStops = maxGradientStops

        context.coordinator.fullLocationData = statisticsData.locationData
        context.coordinator.fullWaves = statisticsData.waves ?? []
        if context.coordinator.fullWaves.isEmpty {
            context.coordinator.fullNonWaves = []
        } else {
            context.coordinator.fullNonWaves = partsBetweenWaves(locationData: statisticsData.locationData, waves: context.coordinator.fullWaves)
        }

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard statisticsData.locationData.count > 1 else {
            return
        }

        if let waves = statisticsData.waves, !waves.isEmpty {
            let nonWaves = partsBetweenWaves(locationData: statisticsData.locationData, waves: waves)

            context.coordinator.addWavePolylines(to: mapView, waves: waves, lineWidth: lineWidth, opacity: waveOpacity, maxPolylinePoints: maxPolylinePoints, maxGradientStops: maxGradientStops)
            context.coordinator.addNonWavePolylines(to: mapView, nonWaves: nonWaves, lineWidth: lineWidth, opacity: nonWaveOpacity, maxPolylinePoints: maxPolylinePoints, maxGradientStops: maxGradientStops)
        } else {
            let downsampledForPolyline = downsamplePolylineCoordinates(statisticsData.locationData, targetCount: maxPolylinePoints)
            let downsampledForGradient = downsampleLocations(statisticsData.locationData, targetCount: maxGradientStops)
            let coordinates = makeCoordinates(from: downsampledForPolyline)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.addPolyline(to: mapView, polyline: polyline, gradientLocations: downsampledForGradient, lineWidth: lineWidth, opacity: waveOpacity)
        }

        let startAnnotation = MKPointAnnotation()
        if let startData = statisticsData.locationData.first {
            startAnnotation.coordinate = CLLocationCoordinate2D(latitude: startData.latitude, longitude: startData.longitude)
            startAnnotation.title = "Start"
            mapView.addAnnotation(startAnnotation)
        }

        let finishAnnotation = MKPointAnnotation()
        if let finishData = statisticsData.locationData.last {
            finishAnnotation.coordinate = CLLocationCoordinate2D(latitude: finishData.latitude, longitude: finishData.longitude)
            finishAnnotation.title = "Finish"
            mapView.addAnnotation(finishAnnotation)
        }

        context.coordinator.fitMap(to: mapView, locationData: statisticsData.locationData)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

extension SpeedGradientStatisticsMap {

    final class Coordinator: NSObject, MKMapViewDelegate {

        var dataHash: Int = 0
        var polylineData: [MKPolyline: PolylineInfo] = [:]
        var fullLocationData: [LocationData] = []
        var fullWaves: [[LocationData]] = []
        var fullNonWaves: [[LocationData]] = []
        var currentLineWidth: CGFloat = 0
        var currentWaveOpacity: CGFloat = 1.0
        var currentNonWaveOpacity: CGFloat = 0.3
        var currentMaxPolylinePoints: Int = MAX_POLYLINE_POINTS
        var currentMaxGradientStops: Int = MAX_GRADIENT_STOPS
        var debounceTimer: Timer?
        var mapViewRef: MKMapView?

        struct PolylineInfo {
            let gradientLocations: [LocationData]
            let lineWidth: CGFloat
            let opacity: CGFloat
        }

        deinit {
            debounceTimer?.invalidate()
            debounceTimer = nil
        }

        func addWavePolylines(to mapView: MKMapView, waves: [[LocationData]], lineWidth: CGFloat, opacity: CGFloat, maxPolylinePoints: Int = MAX_POLYLINE_POINTS, maxGradientStops: Int = MAX_GRADIENT_STOPS) {
            for wave in waves {
                guard wave.count > 1 else { continue }
                let downsampledForPolyline = downsamplePolylineCoordinates(wave, targetCount: maxPolylinePoints)
                let downsampledForGradient = downsampleLocations(wave, targetCount: maxGradientStops)
                let coordinates = makeCoordinates(from: downsampledForPolyline)
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                addPolyline(to: mapView, polyline: polyline, gradientLocations: downsampledForGradient, lineWidth: lineWidth, opacity: opacity)
            }
        }

        func addNonWavePolylines(to mapView: MKMapView, nonWaves: [[LocationData]], lineWidth: CGFloat, opacity: CGFloat, maxPolylinePoints: Int = MAX_POLYLINE_POINTS, maxGradientStops: Int = MAX_GRADIENT_STOPS) {
            for nonWave in nonWaves {
                guard nonWave.count > 1 else { continue }
                let downsampledForPolyline = downsamplePolylineCoordinates(nonWave, targetCount: maxPolylinePoints)
                let downsampledForGradient = downsampleLocations(nonWave, targetCount: maxGradientStops)
                let coordinates = makeCoordinates(from: downsampledForPolyline)
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                addPolyline(to: mapView, polyline: polyline, gradientLocations: downsampledForGradient, lineWidth: lineWidth, opacity: opacity)
            }
        }

        func addPolyline(to mapView: MKMapView, polyline: MKPolyline, gradientLocations: [LocationData], lineWidth: CGFloat, opacity: CGFloat) {
            let info = PolylineInfo(gradientLocations: gradientLocations, lineWidth: lineWidth, opacity: opacity)
            polylineData[polyline] = info
            mapView.addOverlay(polyline)
        }

        func fitMap(to mapView: MKMapView, locationData: [LocationData]) {
            let coordinates = makeCoordinates(from: locationData)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.setVisibleMapRect(
                polyline.boundingMapRect,
                edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40),
                animated: false
            )
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKGradientPolylineRenderer(polyline: polyline)

            let info = polylineData[polyline]
            renderer.lineWidth = info?.lineWidth ?? 2.0
            renderer.lineCap = .round

            if let gradientLocations = info?.gradientLocations, !gradientLocations.isEmpty {
                let (colors, stops) = makeGradientStops(from: gradientLocations)
                renderer.setColors(colors, locations: stops)
            }

            renderer.alpha = info?.opacity ?? 1.0

            return renderer
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self, weak mapView] _ in
                guard let self = self, let mapView = mapView else { return }
                self.updateVisiblePolylines(mapView)
            }
        }

        func updateVisiblePolylines(_ mapView: MKMapView) {
            guard !fullLocationData.isEmpty else { return }

            let visibleRect = mapView.visibleMapRect
            let paddedRect = MKMapRect(
                x: visibleRect.origin.x - visibleRect.width * 0.3,
                y: visibleRect.origin.y - visibleRect.height * 0.3,
                width: visibleRect.width * 1.6,
                height: visibleRect.height * 1.6
            )

            let visibleLocations = filterVisibleLocations(fullLocationData, in: paddedRect)

            guard visibleLocations.count > 1 else { return }

            let downsampledForPolyline = downsamplePolylineCoordinates(visibleLocations, targetCount: currentMaxPolylinePoints)
            let downsampledForGradient = downsampleLocations(visibleLocations, targetCount: currentMaxGradientStops)

            mapView.removeOverlays(mapView.overlays)

            if !fullWaves.isEmpty {
                let visibleWaves = fullWaves.compactMap { wave -> [LocationData]? in
                    let visibleWave = filterVisibleLocations(wave, in: paddedRect)
                    return visibleWave.count > 1 ? visibleWave : nil
                }
                let visibleNonWaves = fullNonWaves.compactMap { nonWave -> [LocationData]? in
                    let visibleNonWave = filterVisibleLocations(nonWave, in: paddedRect)
                    return visibleNonWave.count > 1 ? visibleNonWave : nil
                }
                addWavePolylines(to: mapView, waves: visibleWaves, lineWidth: currentLineWidth, opacity: currentWaveOpacity, maxPolylinePoints: currentMaxPolylinePoints, maxGradientStops: currentMaxGradientStops)
                addNonWavePolylines(to: mapView, nonWaves: visibleNonWaves, lineWidth: currentLineWidth, opacity: currentNonWaveOpacity, maxPolylinePoints: currentMaxPolylinePoints, maxGradientStops: currentMaxGradientStops)
            } else {
                let coordinates = makeCoordinates(from: downsampledForPolyline)
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                addPolyline(to: mapView, polyline: polyline, gradientLocations: downsampledForGradient, lineWidth: currentLineWidth, opacity: currentWaveOpacity)
            }
        }

        func filterVisibleLocations(_ locations: [LocationData], in rect: MKMapRect) -> [LocationData] {
            return locations.filter { location in
                let point = MKMapPoint(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                return rect.contains(point)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let title = annotation.title else { return nil }
            guard title == "Start" || title == "Finish" else { return nil }

            let identifier = title ?? "Something went wrong"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                let type: CircleAnnotationView.MarkerType = title == "Start" ? .start : .finish
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



#Preview {
    let sampleData: [LocationData] = [
        LocationData(timestamp: Date().addingTimeInterval(-100), latitude: 46.891954, longitude: 6.778561, speed: 5.0),
        LocationData(timestamp: Date().addingTimeInterval(-90), latitude: 46.892054, longitude: 6.779561, speed: 8.0),
        LocationData(timestamp: Date().addingTimeInterval(-80), latitude: 46.893054, longitude: 6.780561, speed: 12.0),
        LocationData(timestamp: Date().addingTimeInterval(-70), latitude: 46.894054, longitude: 6.781561, speed: 15.0),
        LocationData(timestamp: Date().addingTimeInterval(-60), latitude: 46.895054, longitude: 6.782561, speed: 10.0),
        LocationData(timestamp: Date().addingTimeInterval(-50), latitude: 46.896054, longitude: 6.783561, speed: 6.0),
    ]

    SpeedGradientStatisticsMap(statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: sampleData)))
        .ignoresSafeArea()
}
