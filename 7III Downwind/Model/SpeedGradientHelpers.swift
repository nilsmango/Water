//
//  SpeedGradientHelpers.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import MapKit
import UIKit

struct DownsamplingCacheKey: Hashable {
    let locationHash: Int
    let targetCount: Int
}

var downsamplingCache: [DownsamplingCacheKey: [LocationData]] = [:]

func downsampleLocations(
    _ locations: [LocationData],
    targetCount: Int = 450
) -> [LocationData] {
    let locationHash = locations.hashValue
    let cacheKey = DownsamplingCacheKey(locationHash: locationHash, targetCount: targetCount)

    if let cached = downsamplingCache[cacheKey] {
        debugMap("Cache hit for downsampled locations")
        return cached
    }

    guard locations.count > targetCount else {
        downsamplingCache[cacheKey] = locations
        return locations
    }

    var selectedIndices: Set<Int> = [0, locations.count - 1]
    selectedIndices.reserveCapacity(targetCount)
    let step = Double(locations.count - 1) / Double(targetCount - 1)

    for i in 1..<(targetCount - 1) {
        let index = Int(round(Double(i) * step))
        selectedIndices.insert(min(max(index, 0), locations.count - 1))
    }

    let finalIndices = Array(selectedIndices).sorted()

    var result: [LocationData] = []
    result.reserveCapacity(finalIndices.count)

    for i in 0..<finalIndices.count {
        let index = finalIndices[i]
        var avgSpeed: Double = 0
        var count = 0

        let startIndex = i > 0 ? finalIndices[i - 1] : 0
        let endIndex = index

        for j in startIndex..<endIndex {
            if let speed = locations[j].speed {
                avgSpeed += speed
                count += 1
            }
        }

        if let speed = locations[index].speed {
            avgSpeed += speed
            count += 1
        }

        avgSpeed = count > 0 ? avgSpeed / Double(count) : 0

        var locationData = locations[index]
        locationData.speed = avgSpeed
        result.append(locationData)
    }

    downsamplingCache[cacheKey] = result
    return result
}

func downsamplePolylineCoordinates(
    _ locations: [LocationData],
    targetCount: Int = 3600
) -> [LocationData] {
    let locationHash = locations.hashValue
    let cacheKey = DownsamplingCacheKey(locationHash: locationHash, targetCount: targetCount)

    if let cached = downsamplingCache[cacheKey] {
        debugMap("Cache hit for polyline coordinates")
        return cached
    }

    guard locations.count > targetCount else {
        downsamplingCache[cacheKey] = locations
        return locations
    }

    var selectedIndices: Set<Int> = [0, locations.count - 1]
    selectedIndices.reserveCapacity(targetCount)
    let step = Double(locations.count - 1) / Double(targetCount - 1)

    for i in 1..<(targetCount - 1) {
        let index = Int(round(Double(i) * step))
        selectedIndices.insert(min(max(index, 0), locations.count - 1))
    }

    let finalIndices = Array(selectedIndices).sorted()
    var result = [LocationData]()
    result.reserveCapacity(finalIndices.count)

    for index in finalIndices {
        result.append(locations[index])
    }

    downsamplingCache[cacheKey] = result
    return result
}

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
