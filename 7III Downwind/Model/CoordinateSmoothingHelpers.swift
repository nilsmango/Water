//
//  CoordinateSmoothingHelpers.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import CoreLocation
import MapKit

internal func makeSmoothedCoordinates(from statistic: [LocationData], removeGpsMistakes: Bool = false) -> [CLLocationCoordinate2D] {
    let rawCoordinates = makeCoordinates(from: statistic)

    guard rawCoordinates.count > 2 else { return rawCoordinates }

    var coordinates = rawCoordinates
    if removeGpsMistakes {
        coordinates = filterGpsMistakes(from: rawCoordinates)
    }

    return applyAngleSmoothing(coordinates: coordinates)
}

internal func makeCoordinates(from statistic: [LocationData]) -> [CLLocationCoordinate2D] {
    var coordinates = [CLLocationCoordinate2D]()
    for location in statistic {
        let locationCoordinates = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        coordinates.append(locationCoordinates)
    }
    return coordinates
}

internal func filterGpsMistakes(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
    guard coordinates.count > 1 else { return coordinates }

    var filtered = [CLLocationCoordinate2D]()
    filtered.append(coordinates[0])

    for i in 1..<coordinates.count {
        let prevLoc = CLLocation(latitude: filtered.last!.latitude, longitude: filtered.last!.longitude)
        let currentLoc = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)

        if prevLoc.distance(from: currentLoc) <= 61.0 {
            filtered.append(coordinates[i])
        }
    }

    return filtered
}

internal func applyAngleSmoothing(coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
    guard coordinates.count > 2 else { return coordinates }

    var smoothed = [CLLocationCoordinate2D]()

    smoothed.append(coordinates[0])

    for i in 1..<(coordinates.count - 1) {
        let prev = coordinates[i - 1]
        let current = coordinates[i]
        let next = coordinates[i + 1]

        let angle = calculateAngle(p1: prev, p2: current, p3: next)

        if angle < 120.0 {
            let smoothingFactor = 0.3

            let smoothedLat = current.latitude * (1.0 - smoothingFactor) +
                             (prev.latitude + next.latitude) * 0.5 * smoothingFactor
            let smoothedLon = current.longitude * (1.0 - smoothingFactor) +
                             (prev.longitude + next.longitude) * 0.5 * smoothingFactor

            smoothed.append(CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLon))
        } else {
            smoothed.append(current)
        }
    }

    smoothed.append(coordinates.last!)

    return smoothed
}

internal func calculateAngle(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D) -> Double {
    let v1Lat = p1.latitude - p2.latitude
    let v1Lon = p1.longitude - p2.longitude
    let v2Lat = p3.latitude - p2.latitude
    let v2Lon = p3.longitude - p2.longitude

    let dotProduct = v1Lat * v2Lat + v1Lon * v2Lon
    let magnitude1 = sqrt(v1Lat * v1Lat + v1Lon * v1Lon)
    let magnitude2 = sqrt(v2Lat * v2Lat + v2Lon * v2Lon)

    guard magnitude1 > 0 && magnitude2 > 0 else { return 180.0 }

    let cosAngle = dotProduct / (magnitude1 * magnitude2)
    let angleRadians = acos(max(-1.0, min(1.0, cosAngle)))
    let angleDegrees = angleRadians * 180.0 / .pi

    return angleDegrees
}
