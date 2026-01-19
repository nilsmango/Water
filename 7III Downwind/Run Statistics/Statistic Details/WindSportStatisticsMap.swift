//
//  WindSportStatisticsMap.swift
//  7III Tracker
//
//  Created by Simon Lang on 03.07.2024.
//

import SwiftUI
import MapKit

private enum AngleMode {
    case menu
    case deleteAngles
    case addAngles
}

struct WindSportStatisticsMap: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var statisticsData: RunStatistic

    var lineWidth = 2.0
    var angleTool = false
    
    @State private var coordinates: [CLLocationCoordinate2D] = []
    @State private var angleToolToDelete: MapAngle?
    @State private var showDeleteAlert = false
    @State private var mode: AngleMode = .menu
    
    let boxPadding: CGFloat = 10
    
    var body: some View {
        MapReader { proxy in
                Map {
                    
                    if let waves = statisticsData.waves, !waves.isEmpty {
                        if statisticsData.locationData.count > 0 {
                            let nonWaves = partsBetweenWaves(locationData: statisticsData.locationData, waves: waves)
                            
                            ForEach(nonWaves.indices, id: \.self) { waveIndex in
                                
                                MapPolyline(coordinates: makeSmoothedCoordinates(from: nonWaves[waveIndex]))
                                    .stroke(
                                        .gray.opacity(0.2),
                                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                
                                
                            }
                        }
                        // Wave lines
                        ForEach(waves.indices, id: \.self) { waveIndex in
                            let coordinates = makeSmoothedCoordinates(from: waves[waveIndex])
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    .neonYellow,
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                        }
                        
                        
                    } else {
                        // Line
                        if statisticsData.locationData.count > 0 {
                            MapPolyline(coordinates: makeSmoothedCoordinates(from: statisticsData.locationData))
                                .stroke(
                                    .neonYellow,
                                    //                                Gradient(colors: downwindManager.createGradientArray(for: statisticsData.locationData, numberOfElementsToKeep: 30)),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        }
                        
                    }
                    
                    // Start and End
                    if let startData = statisticsData.locationData.first {
                        let startCoordinate = CLLocationCoordinate2D(latitude: startData.latitude, longitude: startData.longitude)
                        Annotation("Start", coordinate: startCoordinate) {
                            Circle()
                                .fill(Color.green)
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 15.0)
                            
                        }
                    }
                    
                    if let endData = statisticsData.locationData.last {
                        let endCoordinate = CLLocationCoordinate2D(latitude: endData.latitude, longitude: endData.longitude)
                        Annotation("Finish", coordinate: endCoordinate) {
                            Circle()
                                .fill(Color.red)
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 15.0)
                        }
                    }
                    
                    if angleTool {
                        if coordinates.count == 1 {
                            Annotation("", coordinate: coordinates.first!) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: lineWidth * 2)
                            }
                            
                        } else if coordinates.count == 2 {
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    .green,
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                            
                            Annotation("", coordinate: coordinates.last!) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: lineWidth * 2)
                            }
                            
                        } else if coordinates.count == 3 {
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    .green,
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                            
                            Annotation("", coordinate: coordinates.last!) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: lineWidth * 2)
                            }
                            
                        }
                        
                        if let angles = statisticsData.angles {
                            ForEach(angles) { angleTool in
                                MapPolyline(coordinates: angleTool.coordinates)
                                    .stroke(
                                        mode == .deleteAngles ? Color.red : Color.green,
                                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                
                                Annotation(angleTool.angle, coordinate: angleTool.coordinates[1]) {
                                    ZStack {
                                        Circle()
                                            .fill(mode == .deleteAngles ? Color.red : Color.green)
                                            .frame(width: mode == .deleteAngles ? lineWidth * 10 : lineWidth * 2)
                                        
                                        if mode == .deleteAngles {
                                            Image(systemName: "trash")
                                                .foregroundColor(.white)
                                                .font(.system(size: lineWidth * 5))
                                        }
                                    }
                                    .onTapGesture {
                                        if mode == .deleteAngles {
                                            angleToolToDelete = angleTool
                                            showDeleteAlert = true
                                        }
                                    }
                                }
                                
                            }
                        }
                        
                    }
                }
                
            .onTapGestureBugFix { position in
                if angleTool && mode == .addAngles && coordinates.count < 3 {
                    if let coordinate = proxy.convert(position, from: .local) {
//                        print("Tapped at \(coordinate)")
                        coordinates.append(coordinate)
                        
                    }
                }
            }
            .conditionalDragToMoveLastCoordinate(
                    coordinates: $coordinates,
                    proxy: proxy
                )
            
            .overlay {
                if angleTool {
                    VStack {
                        Spacer()
                        
                        Group {
                            if mode == .menu {
                                HStack {
                                    Button {
                                        mode = .addAngles
                                    } label: {
                                        Label("Add Angle", systemImage: "plus")
                                    }
                                    .foregroundStyle(.white)
                                    .padding(boxPadding)
                                    .background {
                                        RoundedRectangle(cornerRadius: 32.0)
                                            .fill(Color.accentColor)
                                    }
                                    
                                    if statisticsData.angles?.count ?? 0 > 0 {
                                        Button {
                                            mode = .deleteAngles
                                        } label: {
                                            Label("Remove Angles", systemImage: "trash")
                                        }
                                        .foregroundStyle(.white)
                                        .padding(boxPadding)
                                        .background {
                                            RoundedRectangle(cornerRadius: 32.0)
                                                .fill(.red)
                                        }
                                    }
                                }
                            } else {
                                HStack {
                                    Group {
                                        if mode == .deleteAngles {
                                            Text("Tap any Angle to remove it")
                                        } else {
                                            if coordinates.count == 0 {
                                                Text("Tap to add a first leg point")
                                            } else if coordinates.count == 1 {
                                                Text("Tap to add center now, or drag to move first point")
                                            } else if coordinates.count == 2 {
                                                Text("Tap to add last leg, or drag to move center point")
                                            } else if coordinates.count == 3 {
                                                Text("Drag to move last leg point")
                                            }
                                        }
                                    }
                                    .foregroundStyle(.black)
                                    .padding(boxPadding)
                                    .background {
                                        RoundedRectangle(cornerRadius: 16.0)
                                            .fill(.white).opacity(0.6)
                                    }
                                    
                                    VStack {
                                        Button {
                                            if coordinates.count == 3 {
                                                let newTool = MapAngle(coordinates: coordinates)
                                                coordinates = []
                                                statisticsData.angles = (statisticsData.angles ?? []) + [newTool]
                                                downwindManager.saveStatisticAngles(statisticsData: statisticsData)
                                            }
                                            mode = .menu
                                            coordinates = []
                                        } label: {
                                            if coordinates.count == 3 {
                                                Label("Save", systemImage: "checkmark")
                                            } else if mode == .deleteAngles {
                                                Label("Done", systemImage: "checkmark")
                                            } else {
                                                Label("Cancel", systemImage: "xmark")
                                            }
                                        
                                        }
                                        .foregroundStyle(.white)
                                        .padding(boxPadding)
                                        .background {
                                            RoundedRectangle(cornerRadius: 32.0)
                                                .fill(Color.accentColor)
                                        }
                                        
                                        if coordinates.count == 3 {
                                            Button {
                                                mode = .menu
                                                coordinates = []
                                            } label: {
                                                Label("Cancel", systemImage: "xmark")
                                            }
                                            .foregroundStyle(.white)
                                            .padding(boxPadding)
                                            .background {
                                                RoundedRectangle(cornerRadius: 32.0)
                                                    .fill(Color.accentColor)
                                            }
                                        }
                                    }                                    
                                }
                            }
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal)
                    }
                }
            }
            .alert("Remove Angle", isPresented: $showDeleteAlert) {
                Button("Remove", role: .destructive) {
                    if let toolToDelete = angleToolToDelete {
                        statisticsData.angles?.removeAll { $0.id == toolToDelete.id }
                        angleToolToDelete = nil
                        coordinates = []
                        downwindManager.saveStatisticAngles(statisticsData: statisticsData)
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    angleToolToDelete = nil
                }
                
            } message: {
                Text("Are you sure you want to remove this angle measurement?")
            }
        }
    }
}

// MARK: - Coordinate Processing Functions

private func partsBetweenWaves(locationData: [LocationData], waves: [[LocationData]]) -> [[LocationData]] {
    let wavePoints = Set(waves.flatMap { $0 })
    
    var result: [[LocationData]] = []
    var currentPart: [LocationData] = []
    
    for point in locationData {
        if wavePoints.contains(point) {
            if currentPart.count == 1 {
                currentPart = []
                currentPart.append(point)
            } else if !currentPart.isEmpty {
                    currentPart.append(point)
                    result.append(currentPart)
                    currentPart = []
            } else {
                currentPart.append(point)
            }
        } else {
            currentPart.append(point)
        }
    }
    
    if !currentPart.isEmpty {
        result.append(currentPart)
    }
    
    return result
}

#Preview {
    WindSportStatisticsMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)), angleTool: true)
}

