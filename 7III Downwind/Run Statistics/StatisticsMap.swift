//
//  StatisticsMap.swift
//  7III Downwind
//
//  Created by Simon Lang on 20.03.2024.
//

import SwiftUI
import MapKit

struct StatisticsMap: View {
    @ObservedObject var downwindManager: DownwindManager
    
    let statisticsData: RunStatistic
    
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    @State private var coordinatesFactor = 30
    private let maxPointsToShow = 40
    
    @State private var polylineData: [PolylineData] = []
    
    var body: some View {
        let coordinatesCount = statisticsData.locationData.count
        
        Map {
            
                    ForEach(polylineData) { polyline in
                        MapPolyline(coordinates: polyline.coordinates)
                            .stroke(polyline.strokeColor.opacity(0.5), style: StrokeStyle(lineWidth: 10.0, lineCap: .round))
                    }
                
            
            
            
            // start and end annotations
            if coordinatesCount > 0 {
                let startData = statisticsData.locationData.first!
                let startCoordinate = CLLocationCoordinate2D(latitude: startData.latitude, longitude: startData.longitude)
                Annotation("Start", coordinate: startCoordinate) {
                    Circle()
                        .fill(Color.green)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 15.0)
                        
                }
                let endData = statisticsData.locationData.last!
                let endCoordinate = CLLocationCoordinate2D(latitude: endData.latitude, longitude: endData.longitude)
                Annotation("Finish", coordinate: endCoordinate) {
                    Circle()
                        .fill(Color.red)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 15.0)
                }
            }
        }
        .onMapCameraChange { context in
            if abs(mapSpan.latitudeDelta - context.region.span.latitudeDelta) > 0.001  {
                mapSpan = context.region.span
                // calculating coordinates factor
                let newCoordinatesFactor = downwindManager.calculateCoordinatesFactor(context: context, locations: statisticsData.locationData, maxPointsToShow: maxPointsToShow)
                if coordinatesFactor != newCoordinatesFactor {
                    coordinatesFactor = newCoordinatesFactor
                    Task {
                        // coordinates pairs lines
                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: coordinatesCount)
                    }
                }
            }
        }
        .onAppear {
            coordinatesFactor = max(coordinatesCount / maxPointsToShow, 1)
            Task {
                // coordinates pairs lines
                polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: coordinatesCount)
            }
        }
        .navigationTitle(statisticsData.runName)
    }
}

#Preview {
    
    StatisticsMap(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData))
}
