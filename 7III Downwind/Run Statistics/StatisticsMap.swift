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
    
    @Binding var statisticsData: RunStatistic
    
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    @State private var coordinatesFactor = 30
    
    @State private var polylineData: [PolylineData] = []
    
    var editMode = false
    
    var maxPointsToShow: Int {
        if editMode {
            return 35
        } else {
            return 70
        }
    }
    
    var maxPolylines: Int {
        if editMode {
            return 999
        } else {
            return 1600
        }
    }
    
    var lineWidth: Double {
        if editMode {
            return 13.0
        } else {
            return 9.0
        }
    }
    
    var body: some View {
        Map {
            ForEach(polylineData) { polyline in
                if editMode {
                    Annotation("", coordinate: polyline.coordinates.first!) {
                        Menu {
                            Button {
                                Task {
                                    statisticsData = await downwindManager.removePoint(for: statisticsData, coordinate: polyline.coordinates.first!)
                                                                        
                                    // coordinates pairs lines
                                    polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: statisticsData.locationData.count)
                                }
                            } label: {
                                Label("Remove Point", systemImage: "trash")
                            }
                            
                            Button {
                                Task {
                                    statisticsData = await downwindManager.setFinish(for: statisticsData, coordinate: polyline.coordinates.first!)
                                                                        
                                    // coordinates pairs lines
                                    polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: statisticsData.locationData.count)
                                }
                            } label: {
                                Label("Set Finish here", systemImage: "flag.checkered")
                            }
                            
                            Button {
                                Task {
                                    statisticsData = await downwindManager.setStart(for: statisticsData, coordinate: polyline.coordinates.first!)
                                                                        
                                    // coordinates pairs lines
                                    polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: statisticsData.locationData.count)
                                }
                                
                            } label: {
                                Label("Set Start here", systemImage: "play.fill")
                            }
                            
                        } label: {
                            Circle()
                                .fill(.purple.opacity(0.8))
                                .frame(width: lineWidth)
                        }
                        
                    }
                } else {
                    MapPolyline(coordinates: polyline.coordinates)
                        .stroke(polyline.strokeColor.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }

            // start and end annotations + edit polyline
            if statisticsData.locationData.count > 0 {
                if editMode && polylineData.isEmpty == false {
                    let polylineCoordinates = polylineData.compactMap( { $0.coordinates.first })
                    let endCoordinate = [polylineData.last!.coordinates.last!]
                    let combinedArrays = polylineCoordinates + endCoordinate
                    MapPolyline(coordinates: combinedArrays)
                        .stroke(.purple.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
                
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
        .onMapCameraChange(frequency: .onEnd) { context in
            if abs(mapSpan.latitudeDelta - context.region.span.latitudeDelta) > 0.002  {
                mapSpan = context.region.span
                // calculating coordinates factor
                let newCoordinatesFactor = downwindManager.calculateCoordinatesFactor(context: context, locations: statisticsData.locationData, maxPointsToShow: maxPointsToShow, maxPolylines: maxPolylines)
                if coordinatesFactor != newCoordinatesFactor {
                    coordinatesFactor = newCoordinatesFactor
                    Task {
                        // coordinates pairs lines
                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: statisticsData.locationData.count)
                    }
                }
            }
        }
        .onAppear {
            coordinatesFactor = max(statisticsData.locationData.count / maxPointsToShow, 1)
            Task {
                // coordinates pairs lines
                polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, coordinatesFactor: coordinatesFactor, coordinatesCount: statisticsData.locationData.count)
            }
            
        }
    }
}

#Preview {
    
    StatisticsMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)), editMode: true)
}
