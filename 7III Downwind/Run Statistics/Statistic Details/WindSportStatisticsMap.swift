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
                        MapPolyline(coordinates: makeSmoothedCoordinates(from: statisticsData))
                            .stroke(
                                .neonYellow,
//                                Gradient(colors: downwindManager.createGradientArray(for: statisticsData.locationData, numberOfElementsToKeep: 30)),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            
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

// MARK: - Coordinate Processing Functions

private func makeSmoothedCoordinates(from statistic: RunStatistic) -> [CLLocationCoordinate2D] {
    let rawCoordinates = makeCoordinates(from: statistic)
    
    // Only smooth if we have enough points
    guard rawCoordinates.count > 2 else { return rawCoordinates }
    
    // Apply gentle smoothing to reduce sharp angles while keeping all points
    return applyAngleSmoothing(coordinates: rawCoordinates)
}

private func makeCoordinates(from statistic: RunStatistic) -> [CLLocationCoordinate2D] {
    var coordinates = [CLLocationCoordinate2D]()
    for location in statistic.locationData {
        let locationCoordinates = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        coordinates.append(locationCoordinates)
    }
    return coordinates
}

private func applyAngleSmoothing(coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
    guard coordinates.count > 2 else { return coordinates }
    
    var smoothed = [CLLocationCoordinate2D]()
    
    // Keep the first point exactly as is
    smoothed.append(coordinates[0])
    
    // Smooth intermediate points only if they create sharp angles
    for i in 1..<(coordinates.count - 1) {
        let prev = coordinates[i - 1]
        let current = coordinates[i]
        let next = coordinates[i + 1]
        
        // Calculate the angle at this point
        let angle = calculateAngle(p1: prev, p2: current, p3: next)
        
        // Only smooth if the angle is sharp (less than 120 degrees)
        if angle < 120.0 {
            // Apply gentle smoothing - weighted average favoring the original point
            let smoothingFactor = 0.3 // Adjust this value: 0.0 = no smoothing, 1.0 = full averaging
            
            let smoothedLat = current.latitude * (1.0 - smoothingFactor) +
                             (prev.latitude + next.latitude) * 0.5 * smoothingFactor
            let smoothedLon = current.longitude * (1.0 - smoothingFactor) +
                             (prev.longitude + next.longitude) * 0.5 * smoothingFactor
            
            smoothed.append(CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLon))
        } else {
            // Keep the original point if the angle is not sharp
            smoothed.append(current)
        }
    }
    
    // Keep the last point exactly as is
    smoothed.append(coordinates.last!)
    
    return smoothed
}

private func calculateAngle(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D) -> Double {
    // Calculate vectors from p2 to p1 and p2 to p3
    let v1Lat = p1.latitude - p2.latitude
    let v1Lon = p1.longitude - p2.longitude
    let v2Lat = p3.latitude - p2.latitude
    let v2Lon = p3.longitude - p2.longitude
    
    // Calculate dot product and magnitudes
    let dotProduct = v1Lat * v2Lat + v1Lon * v2Lon
    let magnitude1 = sqrt(v1Lat * v1Lat + v1Lon * v1Lon)
    let magnitude2 = sqrt(v2Lat * v2Lat + v2Lon * v2Lon)
    
    // Avoid division by zero
    guard magnitude1 > 0 && magnitude2 > 0 else { return 180.0 }
    
    // Calculate angle in radians, then convert to degrees
    let cosAngle = dotProduct / (magnitude1 * magnitude2)
    let angleRadians = acos(max(-1.0, min(1.0, cosAngle))) // Clamp to avoid numerical errors
    let angleDegrees = angleRadians * 180.0 / .pi
    
    return angleDegrees
}

#Preview {
    WindSportStatisticsMap(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData)))
}

