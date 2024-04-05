//
//  StatisticsMap.swift
//  7III Downwind
//
//  Created by Simon Lang on 20.03.2024.
//

import SwiftUI
import MapKit

struct StatisticsMap: View {
    let statisticsData: RunStatistic
    
    var body: some View {
        Map {
            
            let coordinatesCount = statisticsData.locationData.count
            
            // coordinates pairs lines
            ForEach(statisticsData.locationData.indices, id: \.self) { index in
                if coordinatesCount > index + 1 {
                    let firstData = statisticsData.locationData[index]
                    let firstCoordinate = CLLocationCoordinate2D(latitude: firstData.latitude, longitude: firstData.longitude)
                    let secondData = statisticsData.locationData[index+1]
                    let secondCoordinate = CLLocationCoordinate2D(latitude: secondData.latitude, longitude: secondData.longitude)
                    let segmentCoordinates = [firstCoordinate, secondCoordinate]
                    MapPolyline(coordinates: segmentCoordinates)
                        .stroke(.orange.opacity(0.6), style: StrokeStyle(lineWidth: 10.0, lineCap: .round))
                }
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
        .navigationTitle(statisticsData.runName)
    }
}

#Preview {
    
    StatisticsMap(statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData))
}
