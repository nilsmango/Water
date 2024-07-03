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
    
    var refreshPolyLines: Bool = false
    
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    @State private var polylineData: [PolylineData] = []
    
    @State private var statePolyLineNumber = 100
    
    var editMode = false
    
    @State private var buttonText: String = "Undo All Edits"
    @State private var isFetching: Bool = false
    
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
            return 3.0
        }
    }
    
    var body: some View {
        ZStack {
            Map {
//                ForEach(polylineData) { polyline in
//                    if editMode {
//                        Annotation("", coordinate: polyline.coordinates.first!) {
//                            Menu {
//                                Button {
//                                    Task {
//                                        statisticsData = await downwindManager.removePoint(for: statisticsData, coordinate: polyline.coordinates.first!)
//                                        
//                                        // coordinates pairs lines
//                                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
//                                    }
//                                } label: {
//                                    Label("Remove Point", systemImage: "trash")
//                                }
//                                
//                                Button {
//                                    Task {
//                                        statisticsData = await downwindManager.setFinish(for: statisticsData, coordinate: polyline.coordinates.first!)
//                                        
//                                        // coordinates pairs lines
//                                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
//                                    }
//                                } label: {
//                                    Label("Set Finish here", systemImage: "flag.checkered")
//                                }
//                                
//                                Button {
//                                    Task {
//                                        statisticsData = await downwindManager.setStart(for: statisticsData, coordinate: polyline.coordinates.first!)
//                                        
//                                        // coordinates pairs lines
//                                        polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
//                                    }
//                                    
//                                } label: {
//                                    Label("Set Start here", systemImage: "play.fill")
//                                }
//                                
//                            } label: {
//                                Circle()
//                                    .fill(.purple.opacity(0.8))
//                                    .frame(width: lineWidth)
//                            }
//                            .contentShape(Rectangle())
//                            
//                        }
//                    } else {
//                        MapPolyline(coordinates: polyline.coordinates)
//                            .stroke(polyline.strokeColor.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
//                    }
//                }
                
                
                // start and end annotations + edit polyline
                if statisticsData.locationData.count > 0 {
                    if editMode {
                        MapPolyline(coordinates: makeCoordinates(from: statisticsData))
                            .stroke(.purple.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    } else {
                        MapPolyline(coordinates: makeCoordinates(from: statisticsData))
                            .stroke(
                                .neonYellow,
//                                Gradient(colors: downwindManager.createGradientArray(for: statisticsData.locationData, numberOfElementsToKeep: 30)),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        
                    }
                    
                    
//                    if editMode && polylineData.isEmpty == false {
//                        let polylineCoordinates = polylineData.compactMap( { $0.coordinates.first })
//                        let endCoordinate = [polylineData.last!.coordinates.last!]
//                        let combinedArrays = polylineCoordinates + endCoordinate
//                        MapPolyline(coordinates: combinedArrays)
//                            .stroke(.purple.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
//                    }
                    
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
//            .onMapCameraChange(frequency: .onEnd) { context in
//                if abs(mapSpan.latitudeDelta - context.region.span.latitudeDelta) > 0.002  {
//                    mapSpan = context.region.span
//                    let newPolyLineNumber = downwindManager.calculatePolylineNumber(context: context, locations: statisticsData.locationData, maxPolylinesToShow: maxPointsToShow)
//                    if statePolyLineNumber != newPolyLineNumber {
//                        if newPolyLineNumber <= maxTotalPolyLineNumber {
//                            statePolyLineNumber = newPolyLineNumber
//                        } else {
//                            statePolyLineNumber = maxTotalPolyLineNumber
//                        }
//                        
//                        Task {
//                            polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
//                        }
//                    }
//                }
//            }
//            
            
            if editMode {
                VStack {
                    Spacer()
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
                                    }
                                }
                                
                                isFetching = false
                                buttonText = "Undo All Edits"
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
                }
            }
        }
        
        
//        .onAppear {
//            statePolyLineNumber = maxPointsToShow
//            Task {
//                // coordinates pairs lines
//                polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
//            }
//            
//        }
//        .onChange(of: refreshPolyLines) { _, _ in
//            Task {
//                // coordinates pairs lines
//                polylineData = await downwindManager.createPolylineData(locationData: statisticsData.locationData, numberOfElementsToKeep: statePolyLineNumber, coordinatesCount: statisticsData.locationData.count)
//            }
//        }
    }
}

#Preview {
    
    WindSportStatisticsMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)), editMode: false)
}

private func makeCoordinates(from statistic: RunStatistic) -> [CLLocationCoordinate2D] {
    var coordinates = [CLLocationCoordinate2D]()
    for location in statistic.locationData {
            let locationCoordinates = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            coordinates.append(locationCoordinates)
    }
    // filter the coordinates
//    coordinates = catmullRomSpline(points: coordinates, segments: 4)
    
    return coordinates
}

private func filterClosePoints(_ coordinates: [CLLocationCoordinate2D], minDistance: Double) -> [CLLocationCoordinate2D] {
    guard !coordinates.isEmpty else { return [] }
    
    var filteredCoordinates: [CLLocationCoordinate2D] = [coordinates.first!]

    for coord in coordinates {
        if let lastCoord = filteredCoordinates.last {
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let distance = location.distance(from: lastLocation)
            if distance >= minDistance {
                filteredCoordinates.append(coord)
            }
        }
    }

    return filteredCoordinates
}

private func smoothCoordinates(_ coordinates: [CLLocationCoordinate2D], windowSize: Int = 5) -> [CLLocationCoordinate2D] {
    guard windowSize > 1 else { return coordinates }
    
    var smoothedCoordinates: [CLLocationCoordinate2D] = []
    
    for i in 0..<coordinates.count {
        let start = max(0, i - windowSize / 2)
        let end = min(coordinates.count - 1, i + windowSize / 2)
        let window = coordinates[start...end]
        
        let averageLatitude = window.map { $0.latitude }.reduce(0, +) / Double(window.count)
        let averageLongitude = window.map { $0.longitude }.reduce(0, +) / Double(window.count)
        
        smoothedCoordinates.append(CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude))
    }
    
    return smoothedCoordinates
}

private func catmullRomSpline(points: [CLLocationCoordinate2D], segments: Int) -> [CLLocationCoordinate2D] {
    guard points.count >= 4 else { return points } // We need at least 4 points for Catmull-Rom spline
    
    var smoothedPoints: [CLLocationCoordinate2D] = []
    
    for i in 0..<(points.count - 3) {
        let p0 = points[i]
        let p1 = points[i + 1]
        let p2 = points[i + 2]
        let p3 = points[i + 3]
        
        for j in 0..<segments {
            let t = Double(j) / Double(segments)
            let tt = t * t
            let ttt = tt * t
            
            let q1 = -ttt + 2.0 * tt - t
            let q2 = 3.0 * ttt - 5.0 * tt + 2.0
            let q3 = -3.0 * ttt + 4.0 * tt + t
            let q4 = ttt - tt
            
            let tx = 0.5 * (p0.latitude * q1 + p1.latitude * q2 + p2.latitude * q3 + p3.latitude * q4)
            let ty = 0.5 * (p0.longitude * q1 + p1.longitude * q2 + p2.longitude * q3 + p3.longitude * q4)
            
            smoothedPoints.append(CLLocationCoordinate2D(latitude: tx, longitude: ty))
        }
    }
    
    smoothedPoints.append(points.last!) // Add the last point
    return smoothedPoints
}
