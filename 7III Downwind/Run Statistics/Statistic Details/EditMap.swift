//
//  EditMap.swift
//  7III Tracker
//
//  Created by Simon Lang on 26.06.2025.
//

import SwiftUI
import MapKit

struct EditMap: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var statisticsData: RunStatistic
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?

    let fineLineWidth = 4.0
    let lineWidth = 13.0
    let maxButtonsNumber = 100
    
    @State private var buttonText: String = "Undo All Edits"
    @State private var isFetching: Bool = false
    @State private var hasEdits = false
    
    var body: some View {
        let coordinates = makeCoordinates(from: statisticsData)
        let visibleButtons = getVisibleButtons(coordinates: coordinates, region: visibleRegion)
        
        ZStack {
            Map(position: $mapCameraPosition) {
                // start and end annotations + edit polyline
                if statisticsData.locationData.count > 0 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.purple.opacity(0.3), style: StrokeStyle(lineWidth: fineLineWidth, lineCap: .round))
                    
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
                
                // Add coordinate buttons
                ForEach(visibleButtons.indices, id: \.self) { index in
                    let coordinate = visibleButtons[index]
                    Annotation("", coordinate: coordinate) {
                        Menu {
                            Button {
                                Task {
                                    statisticsData = await downwindManager.removePoint(for: statisticsData, coordinate: coordinate)
                                    
                                    hasEdits = true
                                }
                            } label: {
                                Label("Remove Point", systemImage: "trash")
                            }
                            
                            Button {
                                Task {
                                    statisticsData = await downwindManager.setFinish(for: statisticsData, coordinate: coordinate)
                                    
                                    hasEdits = true
                                }
                            } label: {
                                Label("Set Finish here", systemImage: "flag.checkered")
                            }
                            
                            Button {
                                Task {
                                    statisticsData = await downwindManager.setStart(for: statisticsData, coordinate: coordinate)
                                    
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
                }
            }
            .onAppear {
                hasEdits = downwindManager.hasEdits(for: statisticsData)
            }
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
            }
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
                        Label("Tap a point to edit, zoom to show more points", systemImage: "info.circle")
                            .font(.caption2)
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
    
    private func getVisibleButtons(coordinates: [CLLocationCoordinate2D], region: MKCoordinateRegion?) -> [CLLocationCoordinate2D] {
        guard let region = region, !coordinates.isEmpty else {
            // If no region is set yet, return first 200 coordinates or all if less than 200
            return Array(coordinates.prefix(maxButtonsNumber))
        }
        
        // Calculate visible bounds
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        // Filter coordinates that are within the visible region
        let visibleCoordinates = coordinates.filter { coordinate in
            coordinate.latitude >= minLat &&
            coordinate.latitude <= maxLat &&
            coordinate.longitude >= minLon &&
            coordinate.longitude <= maxLon
        }
        
        // If we have fewer than 200 visible coordinates, expand the search area
        if visibleCoordinates.count < maxButtonsNumber {
            // Calculate distances from region center and sort by distance
            let centerCoordinate = region.center
            let coordinatesWithDistance = coordinates.map { coordinate in
                let distance = calculateDistance(from: centerCoordinate, to: coordinate)
                return (coordinate: coordinate, distance: distance)
            }
            
            let sortedByDistance = coordinatesWithDistance.sorted { $0.distance < $1.distance }
            return Array(sortedByDistance.prefix(maxButtonsNumber).map { $0.coordinate })
        }
        
        // If we have more than 200, take a representative sample
        if visibleCoordinates.count > maxButtonsNumber {
            let step = max(1, visibleCoordinates.count / maxButtonsNumber)
            return stride(from: 0, to: visibleCoordinates.count, by: step)
                .prefix(maxButtonsNumber)
                .map { visibleCoordinates[$0] }
        }
        
        return visibleCoordinates
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLatRad = (to.latitude - from.latitude) * .pi / 180
        let deltaLonRad = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad / 2) * sin(deltaLonRad / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return 6371000 * c // Distance in meters
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
    EditMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)))
}
