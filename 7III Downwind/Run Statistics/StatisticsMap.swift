//
//  StatisticsMap.swift
//  7III Downwind
//
//  Created by Simon Lang on 20.03.2024.
//

import SwiftUI
import MapKit

struct StatisticsMap: View {
    let coordinates: [CLLocationCoordinate2D]
    
    var body: some View {
        Map {
            
            let coordinatesCount = coordinates.count
            
            // coordinates pairs lines
            ForEach(coordinates.indices, id: \.self) { index in
                if coordinatesCount > index + 1 {
                    let segmentCoordinates = [coordinates[index], coordinates[index+1]]
                    MapPolyline(coordinates: segmentCoordinates)
                        .stroke(.orange.opacity(0.6), style: StrokeStyle(lineWidth: 10.0, lineCap: .round))
                }
            }
            
            // start and end annotations
            if coordinatesCount > 0 {
                Annotation("Start", coordinate: coordinates.first!) {
                    Circle()
                        .fill(Color.green)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 15.0)
                        
                }
                                
                Annotation("End", coordinate: coordinates.last!) {
                    Circle()
                        .fill(Color.red)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 15.0)
                }
            
            }
            
        }
    }
}

#Preview {
    StatisticsMap(coordinates: [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4294),
        CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4094)
    ])
}
