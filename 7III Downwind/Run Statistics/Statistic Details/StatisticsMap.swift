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
    
    var refreshPolyLines: Bool = false
    
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    @State private var polylineData: [PolylineData] = []
    
    @State private var statePolyLineNumber = 100
    
    var editMode = false
    
    @State private var buttonText: String = "Undo All Edits"
    @State private var isFetching: Bool = false
    @State private var hasEdits = false
    
    var maxPointsToShow: Int {
        if let workoutType = statisticsData.workoutType {
            if workoutType.isDWSport {
                if editMode {
                    return 45
                } else {
                    return 70
                }
            } else {
                if editMode {
                    return 45
                } else {
                    return 140
                }
            }
        } else {
            if editMode {
                return 45
            } else {
                return 70
            }
        }
    }
    
    // TODO: change this one if we get crashes (500-750 might be enough)
    var maxTotalPolyLineNumber: Int {
        if editMode {
            return 1000
        } else {
            return 1000
        }
    }
    
    var lineWidth: Double {
        if editMode {
            return 13.0
        } else {
            return 9.0
        }
    }
    let fineLineWidth = 4.0
    
    var body: some View {
        ZStack {
            Map {
                ForEach(polylineData) { polyline in
                    if editMode {
                        Annotation("", coordinate: polyline.coordinates.first!) {
                            Menu {
                                Button {
                                    Task {
                                        statisticsData = await downwindManager.removePoint(for: statisticsData, coordinate: polyline.coordinates.first!)
                                        
                                        // coordinates pairs lines
                                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
                                        
                                        hasEdits = true
                                    }
                                } label: {
                                    Label("Remove Point", systemImage: "trash")
                                }
                                
                                Button {
                                    Task {
                                        statisticsData = await downwindManager.setFinish(for: statisticsData, coordinate: polyline.coordinates.first!)
                                        
                                        // coordinates pairs lines
                                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
                                        
                                        hasEdits = true
                                    }
                                } label: {
                                    Label("Set Finish here", systemImage: "flag.checkered")
                                }
                                
                                Button {
                                    Task {
                                        statisticsData = await downwindManager.setStart(for: statisticsData, coordinate: polyline.coordinates.first!)
                                        
                                        // coordinates pairs lines
                                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
                                        
                                        hasEdits = true
                                    }
                                    
                                } label: {
                                    Label("Set Start here", systemImage: "play.fill")
                                }
                                
                            } label: {
                                Circle()
                                    .fill(.purple.opacity(0.8))
                                    .frame(width: lineWidth)
                            }
                            .contentShape(Rectangle())
                            
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
                            .stroke(.purple.opacity(0.3), style: StrokeStyle(lineWidth: fineLineWidth, lineCap: .round))
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
                    let newPolyLineNumber = downwindManager.calculatePolylineNumber(context: context, locations: statisticsData.locationData, maxPolylinesToShow: maxPointsToShow)
                    if statePolyLineNumber != newPolyLineNumber {
                        if newPolyLineNumber <= maxTotalPolyLineNumber {
                            statePolyLineNumber = newPolyLineNumber
                        } else {
                            statePolyLineNumber = maxTotalPolyLineNumber
                        }
                        
                        Task {
                            polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
                        }
                    }
                }
            }
            if editMode {
                VStack {
                    Spacer()
                    
                    if hasEdits {
                        HStack {
                            Spacer()
                            Button(action: {
                                isFetching = true
                                buttonText = "Loading Data..."
                                
                                downwindManager.revertChangesForRoute(for: statisticsData) { ogStatistic in
                                    if let ogStatistic = ogStatistic {
                                        statisticsData = ogStatistic
                                        
                                        Task {
                                            polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
                                            
                                            isFetching = false
                                            hasEdits = false
                                            buttonText = "Undo All Edits"
                                        }
                                    } else {
                                        isFetching = false
                                        hasEdits = downwindManager.hasEdits(for: statisticsData)
                                        buttonText = "Undo All Edits"
                                    }
                                }
                                
                            }, label: {
                                Label(buttonText, systemImage: "arrow.counterclockwise")
                            })
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .disabled(isFetching)
                        }
                        .padding(.trailing, 10)
                        .padding(.bottom, 10)
                    }
                    
                    HStack {
                        Spacer()
                        Label("Select a point to edit", systemImage: "info.circle")
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 15.0)
                                    .foregroundStyle(.listForeground)
                                
                            }
                    }
                    .padding(.trailing, 10)
                    .padding(.bottom, 5)
                }
            }
        }
        .onAppear {
            statePolyLineNumber = maxPointsToShow
            Task {
                // coordinates pairs lines
                polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
            }
            hasEdits = downwindManager.hasEdits(for: statisticsData)
        }
        .onChange(of: refreshPolyLines) { _, _ in
            Task {
                // coordinates pairs lines
                polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
            }
        }
    }
}

#Preview {
    
    StatisticsMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)), editMode: false)
}
