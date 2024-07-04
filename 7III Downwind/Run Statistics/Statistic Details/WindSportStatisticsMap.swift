//
//  WindSportStatisticsMap.swift
//  7III Tracker
//
//  Created by Simon Lang on 03.07.2024.
//

import SwiftUI
import MapKit


struct WindSportStatisticsMap: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var statisticsData: RunStatistic

    var lineWidth = 2.0
    
    var body: some View {
            Map {
                // start and end annotations + edit polyline
                if statisticsData.locationData.count > 0 {
                        MapPolyline(coordinates: makeCoordinates(from: statisticsData))
                            .stroke(
                                .neonYellow,
//                                Gradient(colors: downwindManager.createGradientArray(for: statisticsData.locationData, numberOfElementsToKeep: 30)),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                            
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
    }
}

private func makeCoordinates(from statistic: RunStatistic) -> [CLLocationCoordinate2D] {
    var coordinates = [CLLocationCoordinate2D]()
    for location in statistic.locationData {
            let locationCoordinates = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            coordinates.append(locationCoordinates)
    }
    return coordinates
}

#Preview {
    WindSportStatisticsMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)))
}

