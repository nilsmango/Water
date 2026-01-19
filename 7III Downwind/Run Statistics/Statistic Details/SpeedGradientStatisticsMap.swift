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
        
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard statisticsData.locationData.count > 1 else {
            return
        }
        
        if let waves = statisticsData.waves, !waves.isEmpty {
            let nonWaves = partsBetweenWaves(locationData: statisticsData.locationData, waves: waves)
            
            context.coordinator.addWavePolylines(to: mapView, waves: waves, lineWidth: lineWidth, opacity: waveOpacity)
            context.coordinator.addNonWavePolylines(to: mapView, nonWaves: nonWaves, lineWidth: lineWidth, opacity: nonWaveOpacity)
        } else {
            let coordinates = makeCoordinates(from: statisticsData.locationData)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.addPolyline(to: mapView, polyline: polyline, locations: statisticsData.locationData, lineWidth: lineWidth, opacity: waveOpacity)
        }
        
        let startAnnotation = MKPointAnnotation()
        let startData = statisticsData.locationData.first!
        startAnnotation.coordinate = CLLocationCoordinate2D(latitude: startData.latitude, longitude: startData.longitude)
        startAnnotation.title = "Start"
        mapView.addAnnotation(startAnnotation)
        
        let finishAnnotation = MKPointAnnotation()
        let finishData = statisticsData.locationData.last!
        finishAnnotation.coordinate = CLLocationCoordinate2D(latitude: finishData.latitude, longitude: finishData.longitude)
        finishAnnotation.title = "Finish"
        mapView.addAnnotation(finishAnnotation)
        
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

        struct PolylineInfo {
            let locations: [LocationData]
            let lineWidth: CGFloat
            let opacity: CGFloat
        }

        func addWavePolylines(to mapView: MKMapView, waves: [[LocationData]], lineWidth: CGFloat, opacity: CGFloat) {
            for wave in waves {
                guard wave.count > 1 else { continue }
                let coordinates = makeCoordinates(from: wave)
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                addPolyline(to: mapView, polyline: polyline, locations: wave, lineWidth: lineWidth, opacity: opacity)
            }
        }

        func addNonWavePolylines(to mapView: MKMapView, nonWaves: [[LocationData]], lineWidth: CGFloat, opacity: CGFloat) {
            for nonWave in nonWaves {
                guard nonWave.count > 1 else { continue }
                let coordinates = makeCoordinates(from: nonWave)
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                addPolyline(to: mapView, polyline: polyline, locations: nonWave, lineWidth: lineWidth, opacity: opacity)
            }
        }

        func addPolyline(to mapView: MKMapView, polyline: MKPolyline, locations: [LocationData], lineWidth: CGFloat, opacity: CGFloat) {
            let info = PolylineInfo(locations: locations, lineWidth: lineWidth, opacity: opacity)
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

            if let locations = info?.locations, !locations.isEmpty {
                let (colors, stops) = makeGradientStops(from: locations)
                renderer.setColors(colors, locations: stops)
            }

            renderer.alpha = info?.opacity ?? 1.0

            return renderer
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
