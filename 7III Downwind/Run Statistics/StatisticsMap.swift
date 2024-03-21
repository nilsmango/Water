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
            
            let coordinatesCount = statisticsData.data.count
            
            // coordinates pairs lines
            ForEach(statisticsData.data.indices, id: \.self) { index in
                if coordinatesCount > index + 1 {
                    let firstData = statisticsData.data[index]
                    let firstCoordinate = CLLocationCoordinate2D(latitude: firstData.latitude, longitude: firstData.longitude)
                    let secondData = statisticsData.data[index+1]
                    let secondCoordinate = CLLocationCoordinate2D(latitude: secondData.latitude, longitude: secondData.longitude)
                    let segmentCoordinates = [firstCoordinate, secondCoordinate]
                    MapPolyline(coordinates: segmentCoordinates)
                        .stroke(.orange.opacity(0.6), style: StrokeStyle(lineWidth: 10.0, lineCap: .round))
                }
            }
            
            // start and end annotations
            if coordinatesCount > 0 {
                let startData = statisticsData.data.first!
                let startCoordinate = CLLocationCoordinate2D(latitude: startData.latitude, longitude: startData.longitude)
                Annotation("Start", coordinate: startCoordinate) {
                    Circle()
                        .fill(Color.green)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 15.0)
                        
                }
                let endData = statisticsData.data.last!
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
    
    StatisticsMap(statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, data: [StatisticData(date: Date().addingTimeInterval(2), latitude: 37.7748, longitude: -122.4197, speed: 11.790322769578067),
                                                                                                                                                                            StatisticData(date: Date().addingTimeInterval(4), latitude: 37.7748, longitude: -122.41958, speed: 11.991023390499704),
                                                                                                                                                                            StatisticData(date: Date().addingTimeInterval(6), latitude: 37.77479826565036, longitude: -122.41952333322953, speed: 7.317224042312246),
                                                                                                                                                                            StatisticData(date: Date().addingTimeInterval(7), latitude: 37.77476060704628, longitude: -122.41926475227716, speed: 7.485536747974884),
                                                                                                                                                                            StatisticData(date: Date().addingTimeInterval(8), latitude: 37.77477, longitude: -122.41922865397946, speed: 10.403621380501487)]))
}
