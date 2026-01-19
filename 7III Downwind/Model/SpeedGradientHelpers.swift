//
//  SpeedGradientHelpers.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import MapKit
import UIKit

func makeGradientStops(
    from data: [LocationData]
) -> ([UIColor], [CGFloat]) {

    debugMap("Creating gradient stops")

    let clLocations = data.map {
        CLLocation(latitude: $0.latitude, longitude: $0.longitude)
    }

    var distances: [CLLocationDistance] = [0]
    for i in 1..<clLocations.count {
        let d = clLocations[i].distance(from: clLocations[i - 1])
        distances.append(distances.last! + d)
    }

    let totalDistance = distances.last ?? 0
    debugMap("Total distance: \(totalDistance)m")

    if totalDistance <= 0 {
        debugMap("⚠️ Total distance is zero")
    }

    let speeds = data.compactMap { $0.speed }
    let maxSpeed = speeds.max() ?? 0
    debugMap("Max speed: \(maxSpeed)m/s")

    var colors: [UIColor] = []
    var locations: [CGFloat] = []

    for i in data.indices {
        let unitDistance = totalDistance > 0 ? distances[i] / totalDistance : 0
        let speed = data[i].speed ?? 0
        let t = maxSpeed > 0 ? speed / maxSpeed : 0

        debugMap("Point \(i): unitDistance=\(unitDistance), speed=\(speed)")

        colors.append(colorForSpeed(t))
        locations.append(CGFloat(unitDistance))
    }

    // 🔴 CRITICAL: ensure monotonic increasing locations
    let zipped = zip(locations, colors)
        .sorted { $0.0 < $1.0 }

    let finalLocations = zipped.map { $0.0 }
    let finalColors = zipped.map { $0.1 }

    return (finalColors, finalLocations)
}

func colorForSpeed(_ t: Double) -> UIColor {
    if t <= 0.5 {
        // red → yellow
        return UIColor(
            red: 1,
            green: CGFloat(t * 2),
            blue: 0,
            alpha: 1
        )
    } else {
        // yellow → green
        return UIColor(
            red: CGFloat(1 - (t - 0.5) * 2),
            green: 1,
            blue: 0,
            alpha: 1
        )
    }
}
