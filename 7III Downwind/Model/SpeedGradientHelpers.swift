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

struct GradientCacheKey: Hashable {
    let locationHash: Int
    let maxSpeed: Double?
}

var downsamplingCache: [DownsamplingCacheKey: [LocationData]] = [:]
var gradientStopsCache: [GradientCacheKey: ([UIColor], [CGFloat])] = [:]

let MAX_POLYLINE_POINTS = 1000
let MAX_GRADIENT_STOPS = 500

func downsampleLocations(
    _ locations: [LocationData],
    targetCount: Int = MAX_GRADIENT_STOPS
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
    from data: [LocationData],
    maxSpeed overrideMaxSpeed: Double? = nil
) -> ([UIColor], [CGFloat]) {

    let locationHash = data.hashValue
    let cacheKey = GradientCacheKey(locationHash: locationHash, maxSpeed: overrideMaxSpeed)

    if let cached = gradientStopsCache[cacheKey] {
        debugMap("Cache hit for gradient stops")
        return cached
    }

    debugMap("Creating gradient stops")

    var distances: [CLLocationDistance] = [0]
    for i in 1..<data.count {
        let lat1 = data[i - 1].latitude * .pi / 180
        let lon1 = data[i - 1].longitude * .pi / 180
        let lat2 = data[i].latitude * .pi / 180
        let lon2 = data[i].longitude * .pi / 180

        let dlat = lat2 - lat1
        let dlon = lon2 - lon1

        let a = sin(dlat / 2) * sin(dlat / 2) +
                cos(lat1) * cos(lat2) *
                sin(dlon / 2) * sin(dlon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        let distance = 6371000 * c

        distances.append(distances.last! + distance)
    }

    let totalDistance = distances.last ?? 0
    debugMap("Total distance: \(totalDistance)m")

    if totalDistance <= 0 {
        debugMap("⚠️ Total distance is zero")
    }

    let maxSpeed = overrideMaxSpeed ?? maxSpeed(in: data)
    debugMap("Max speed: \(maxSpeed)m/s")

    var colors: [UIColor] = []
    var stops: [CGFloat] = []

    colors.reserveCapacity(data.count)
    stops.reserveCapacity(data.count)

    for i in data.indices {
        let unitDistance = totalDistance > 0 ? distances[i] / totalDistance : 0
        let speed = data[i].speed ?? 0
        let t = maxSpeed > 0 ? speed / maxSpeed : 0

        colors.append(colorForSpeed(t))
        stops.append(CGFloat(unitDistance))
    }

    let result = (colors, stops)
    gradientStopsCache[cacheKey] = result

    return result
}

func maxSpeed(in locations: [LocationData]) -> Double {
    locations.compactMap(\.speed).max() ?? 0
}

func visibleLocationSegments(
    from locations: [LocationData],
    in rect: MKMapRect
) -> [[LocationData]] {
    var segments: [[LocationData]] = []
    var currentSegment: [LocationData] = []

    for index in locations.indices {
        let location = locations[index]
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let point = MKMapPoint(coordinate)

        if rect.contains(point) {
            if currentSegment.isEmpty, index > locations.startIndex {
                currentSegment.append(locations[locations.index(before: index)])
            }
            currentSegment.append(location)
        } else if !currentSegment.isEmpty {
            currentSegment.append(location)
            if currentSegment.count > 1 {
                segments.append(currentSegment)
            }
            currentSegment.removeAll(keepingCapacity: true)
        }
    }

    if currentSegment.count > 1 {
        segments.append(currentSegment)
    }

    return segments
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
