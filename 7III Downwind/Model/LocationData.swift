//
//  StatisticData.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import Foundation

struct LocationData: Codable, Equatable, Hashable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    
    // speed in m/s from CoreLocation
    var speed: Double?
    var verticalAccuracy: Double?
    
    static func == (lhs: LocationData, rhs: LocationData) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.speed == rhs.speed
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(speed)
    }
}

/// Directional metrics inferred from a wind-sport GPS route.
///
/// Upwind and downwind are deliberately derived rather than persisted: edited and
/// imported routes therefore always use the same analysis as newly recorded ones.
struct WindRouteAnalysis: Equatable, Sendable {
    let upwindDistance: Double
    let downwindDistance: Double
    let upwindDuration: TimeInterval
    let downwindDuration: TimeInterval
    let idleDuration: TimeInterval
    let turnAngles: [Double]
    let mapSegments: [WindRouteMapSegment]
    let angleMarkers: [WindRouteAngleMarker]
    let directionConfidence: Double

    var downwindToUpwindTimePercentage: Double? {
        guard upwindDuration > 0 else { return nil }
        return downwindDuration / upwindDuration * 100
    }

    var averageTurnAngle: Double? {
        guard !turnAngles.isEmpty else { return nil }
        return turnAngles.reduce(0, +) / Double(turnAngles.count)
    }

    /// The widest clean angle between two accepted upwind legs.
    var bestTurnAngle: Double? {
        turnAngles.max()
    }
}

enum WindRouteDirection: String, Equatable, Hashable, Sendable {
    case upwind
    case downwind
    case idle
}

struct WindRouteCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct WindRouteMapSegment: Identifiable, Equatable, Sendable {
    let id: Int
    let direction: WindRouteDirection
    let coordinates: [WindRouteCoordinate]
}

struct WindRouteAngleMarker: Identifiable, Equatable, Sendable {
    let id: Int
    let angle: Double
    let incomingPoint: WindRouteCoordinate
    let incomingTurnPoint: WindRouteCoordinate
    let vertex: WindRouteCoordinate
    let outgoingTurnPoint: WindRouteCoordinate
    let outgoingPoint: WindRouteCoordinate
}

/// Infers sustained course modes and recurring tack pairs, then detects stable
/// turns between the two upwind headings. Simpler two-direction routes fall back
/// to classification against their dominant travel axis.
///
/// GPS usually provides enough geometry for deterministic analysis. A known wind
/// bearing resolves routes whose windward and leeward reaches look alike when
/// travel has a meaningful component along that bearing.
func analyzeWindRoute(
    from rawLocations: [LocationData],
    reverseDirections: Bool = false,
    windFromBearing: Double? = nil
) -> WindRouteAnalysis? {
    let locations = rawLocations
        .filter { $0.latitude.isFinite && $0.longitude.isFinite }
        .sorted { $0.timestamp < $1.timestamp }

    guard locations.count >= 20 else { return nil }

    let referenceLatitude = locations.map(\.latitude).reduce(0, +) / Double(locations.count)
    let projected = locations.map { windProjectedPoint(for: $0, referenceLatitude: referenceLatitude) }
    var intervals = [WindRouteInterval]()
    intervals.reserveCapacity(locations.count - 1)

    for index in 1..<locations.count {
        let start = locations[index - 1]
        let end = locations[index]
        let duration = end.timestamp.timeIntervalSince(start.timestamp)
        guard duration > 0 else { continue }

        let dx = projected[index].x - projected[index - 1].x
        let dy = projected[index].y - projected[index - 1].y
        let distance = hypot(dx, dy)
        let derivedSpeed = distance / duration
        let reportedSpeeds = [start.speed, end.speed].compactMap { speed -> Double? in
            guard let speed, speed.isFinite, speed >= 0 else { return nil }
            return speed
        }
        let reportedSpeed = reportedSpeeds.isEmpty
            ? derivedSpeed
            : reportedSpeeds.reduce(0, +) / Double(reportedSpeeds.count)

        intervals.append(
            WindRouteInterval(
                startIndex: index - 1,
                endIndex: index,
                midpoint: start.timestamp.addingTimeInterval(duration / 2),
                duration: duration,
                distance: distance,
                dx: dx,
                dy: dy,
                speed: reportedSpeed,
                isGap: duration > WindRouteConstants.maximumContinuousInterval || derivedSpeed > WindRouteConstants.maximumPlausibleSpeed,
                courseDX: dx,
                courseDY: dy
            )
        )
    }

    guard intervals.count >= 15 else { return nil }

    // A symmetric time window suppresses one-second GPS heading noise without
    // rounding off normal tacks and jibes.
    for index in intervals.indices {
        let lowerTime = intervals[index].midpoint.addingTimeInterval(-WindRouteConstants.courseSmoothingRadius)
        let upperTime = intervals[index].midpoint.addingTimeInterval(WindRouteConstants.courseSmoothingRadius)
        var lower = index
        var upper = index
        while lower > intervals.startIndex, intervals[lower - 1].midpoint >= lowerTime {
            lower -= 1
        }
        while upper + 1 < intervals.endIndex, intervals[upper + 1].midpoint <= upperTime {
            upper += 1
        }

        var courseDX = 0.0
        var courseDY = 0.0
        var speeds = [Double]()
        for neighbor in lower...upper where !intervals[neighbor].isGap {
            courseDX += intervals[neighbor].dx
            courseDY += intervals[neighbor].dy
            speeds.append(intervals[neighbor].speed)
        }
        intervals[index].courseDX = courseDX
        intervals[index].courseDY = courseDY
        if !speeds.isEmpty {
            speeds.sort()
            intervals[index].speed = speeds[speeds.count / 2]
        }
    }

    let movingIntervals = intervals.filter {
        !$0.isGap && $0.speed >= WindRouteConstants.idleSpeed && hypot($0.courseDX, $0.courseDY) >= 2
    }
    guard movingIntervals.count >= 15 else { return nil }

    // Principal component analysis of moving positions finds the route's dominant
    // (wind) axis without needing weather data or a manually entered wind bearing.
    var totalWeight = 0.0
    var meanX = 0.0
    var meanY = 0.0
    for interval in movingIntervals {
        let point = projected[interval.endIndex]
        let weight = min(interval.duration, 3)
        totalWeight += weight
        meanX += point.x * weight
        meanY += point.y * weight
    }
    guard totalWeight > 0 else { return nil }
    meanX /= totalWeight
    meanY /= totalWeight

    var covarianceXX = 0.0
    var covarianceXY = 0.0
    var covarianceYY = 0.0
    for interval in movingIntervals {
        let point = projected[interval.endIndex]
        let weight = min(interval.duration, 3)
        let x = point.x - meanX
        let y = point.y - meanY
        covarianceXX += x * x * weight
        covarianceXY += x * y * weight
        covarianceYY += y * y * weight
    }
    covarianceXX /= totalWeight
    covarianceXY /= totalWeight
    covarianceYY /= totalWeight

    let axisAngle = 0.5 * atan2(2 * covarianceXY, covarianceXX - covarianceYY)
    let axisX = cos(axisAngle)
    let axisY = sin(axisAngle)
    let eigenSpread = sqrt(pow(covarianceXX - covarianceYY, 2) + 4 * covarianceXY * covarianceXY)
    let largeEigenvalue = max(0, (covarianceXX + covarianceYY + eigenSpread) / 2)
    let smallEigenvalue = max(1, (covarianceXX + covarianceYY - eigenSpread) / 2)
    guard largeEigenvalue >= 400 else { return nil }
    let axisElongation = largeEigenvalue / smallEigenvalue

    var positiveSpeeds = [(value: Double, weight: Double)]()
    var negativeSpeeds = [(value: Double, weight: Double)]()
    var positiveDuration = 0.0
    var negativeDuration = 0.0
    var positiveCrossValues = [(value: Double, weight: Double)]()
    var negativeCrossValues = [(value: Double, weight: Double)]()

    for interval in movingIntervals {
        let length = hypot(interval.courseDX, interval.courseDY)
        guard length > 0 else { continue }
        let along = (interval.courseDX * axisX + interval.courseDY * axisY) / length
        let cross = abs(-interval.courseDX * axisY + interval.courseDY * axisX) / length
        let weight = min(interval.duration, 3)
        if along >= 0 {
            positiveSpeeds.append((interval.speed, weight))
            positiveDuration += interval.duration
            positiveCrossValues.append((cross, weight))
        } else {
            negativeSpeeds.append((interval.speed, weight))
            negativeDuration += interval.duration
            negativeCrossValues.append((cross, weight))
        }
    }

    let windUnit: (x: Double, y: Double)? = windFromBearing.flatMap { bearing in
        guard bearing.isFinite else { return nil }
        let radians = bearing * .pi / 180
        return (sin(radians), cos(radians))
    }
    let movingDuration = positiveDuration + negativeDuration
    guard movingDuration > 0,
          windUnit != nil || (
            positiveDuration >= max(45, movingDuration * 0.08)
                && negativeDuration >= max(45, movingDuration * 0.08)
          ) else {
        return nil
    }
    let positiveMedianSpeed = windWeightedMedian(positiveSpeeds) ?? 0
    let negativeMedianSpeed = windWeightedMedian(negativeSpeeds) ?? 0
    let positiveTypicalCross = windWeightedMedian(positiveCrossValues) ?? 0
    let negativeTypicalCross = windWeightedMedian(negativeCrossValues) ?? 0

    let maximumMedianSpeed = max(positiveMedianSpeed, negativeMedianSpeed, 0.1)
    let speedSeparation = abs(positiveMedianSpeed - negativeMedianSpeed) / maximumMedianSpeed
    let crossSeparation = abs(positiveTypicalCross - negativeTypicalCross)

    // Large, sustained legs away from the dominant axis identify upwind tacking.
    // Downwind runs have the much shallower zigzag described by their lower typical
    // cross-axis component. A weighted median makes the brief circular path
    // through a gybe unable to overwhelm the much longer straight legs.
    // Speed is only a fallback for routes whose geometry is not decisive.
    let windAlignment = windUnit.map { axisX * $0.x + axisY * $0.y }
    // A wind bearing cannot resolve two travel directions that are almost
    // perpendicular to it. A few degrees of GPS or weather error would swap
    // the labels for the entire route (as with crosswind swell riding).
    let windBearingResolvesAxis = windAlignment.map { abs($0) >= 0.25 } ?? false
    let positiveIsUpwind: Bool
    if let windAlignment, windBearingResolvesAxis {
        positiveIsUpwind = windAlignment >= 0
    } else if crossSeparation >= 0.05 {
        positiveIsUpwind = positiveTypicalCross > negativeTypicalCross
    } else if speedSeparation >= 0.12 {
        positiveIsUpwind = positiveMedianSpeed < negativeMedianSpeed
    } else {
        return nil
    }

    // GPS extent alone cannot resolve a broad downwind reach from two upwind
    // tacks: a tack nearly perpendicular to the extent can project onto the
    // downwind half of this axis. Prefer sustained course modes when one mode
    // is distinctly wavier and the other two form a plausible windward pair.
    let headingModes = windUnit == nil ? windHeadingModes(in: intervals) : nil
    func classifiedRoute(reversed: Bool) -> (
        categories: [WindRouteCategory],
        angles: [Double],
        markers: [WindRouteAngleMarker],
        upwindLocationRanges: [ClosedRange<Int>]
    ) {
        let upwindAxisSign = (positiveIsUpwind != reversed) ? 1.0 : -1.0
        let initialCategories = intervals.enumerated().map { index, interval -> WindRouteCategory in
            guard !interval.isGap,
                  interval.speed >= WindRouteConstants.idleSpeed else {
                return .idle
            }
            if let headingModes {
                let isUpwind = headingModes.upwindByInterval[index] != reversed
                return isUpwind ? .upwind : .downwind
            }
            let along = interval.courseDX * axisX + interval.courseDY * axisY
            return along * upwindAxisSign >= 0 ? .upwind : .downwind
        }
        let categories = windStabilizedCategories(
            initialCategories,
            intervals: intervals,
            axisX: axisX,
            axisY: axisY
        )
        let angleResult = windTurnAngles(
            locations: locations,
            projected: projected,
            intervals: intervals,
            categories: categories,
            axisX: axisX,
            axisY: axisY,
            upwindSides: reversed ? nil : headingModes?.upwindSideByInterval
        )
        return (categories, angleResult.angles, angleResult.markers, angleResult.upwindLocationRanges)
    }

    let inferredRoute = classifiedRoute(reversed: false)
    let oppositeRoute = classifiedRoute(reversed: true)
    // A broad reach can make the less-tacked direction look more cross-axis,
    // especially when wind and swell differ. Count only substantial, repeated
    // upwind turns as evidence for changing the inferred polarity. A single
    // small bend in an otherwise continuous leg cannot reverse a whole route.
    func substantialTurnCount(_ angles: [Double]) -> Int {
        angles.filter { (35...80).contains($0) }.count
    }
    let inferredTurns = substantialTurnCount(inferredRoute.angles)
    let oppositeTurns = substantialTurnCount(oppositeRoute.angles)
    let turnEvidenceReversesDirections = windUnit == nil
        && oppositeTurns >= max(2, inferredTurns + 2)
        && Double(oppositeTurns) >= Double(inferredTurns) * 1.5
    let selectedRoute = (reverseDirections != turnEvidenceReversesDirections)
        ? oppositeRoute : inferredRoute
    var categories = selectedRoute.categories

    // A tack or rounded jibe can briefly point the GPS trace back downwind. Once
    // two clean upwind legs establish a real turn, keep that short connecting
    // movement with the upwind section. Only the turns found from the original
    // classification may change colors; that prevents one correction from
    // recursively manufacturing more angles farther into a downwind run.
    for range in selectedRoute.upwindLocationRanges {
        for index in intervals.indices
            where intervals[index].startIndex >= range.lowerBound
                && intervals[index].endIndex <= range.upperBound
                && !intervals[index].isGap {
            categories[index] = .upwind
        }
    }

    var upwindDistance = 0.0
    var downwindDistance = 0.0
    var upwindDuration = 0.0
    var downwindDuration = 0.0
    var idleDuration = 0.0
    for index in intervals.indices {
        switch categories[index] {
        case .upwind:
            upwindDistance += intervals[index].distance
            upwindDuration += intervals[index].duration
        case .downwind:
            downwindDistance += intervals[index].distance
            downwindDuration += intervals[index].duration
        case .idle:
            idleDuration += intervals[index].duration
        }
    }

    let mapSegments = windMapSegments(
        locations: locations,
        intervals: intervals,
        categories: categories
    )
    let directionBalance = min(positiveDuration, negativeDuration) / max(positiveDuration, negativeDuration, 0.1)
    let shapeConfidence = min(1, max(0, (axisElongation - 1) / 3))
    let cueConfidence = min(1, max(speedSeparation * 2.5, crossSeparation * 1.5))
    let cueBasedConfidence = max(
        min(1, cueConfidence * 0.6 + shapeConfidence * 0.2 + directionBalance * 0.2),
        headingModes?.confidence ?? 0
    )
    let confidence = windBearingResolvesAxis ? max(0.8, cueBasedConfidence)
        : (turnEvidenceReversesDirections ? min(cueBasedConfidence, 0.75) : cueBasedConfidence)

    return WindRouteAnalysis(
        upwindDistance: upwindDistance,
        downwindDistance: downwindDistance,
        upwindDuration: upwindDuration,
        downwindDuration: downwindDuration,
        idleDuration: idleDuration,
        turnAngles: selectedRoute.angles,
        mapSegments: mapSegments,
        angleMarkers: selectedRoute.markers,
        directionConfidence: confidence
    )
}

private enum WindRouteConstants {
    static let earthRadius = 6_371_000.0
    static let idleSpeed = 1.0 // m/s; below this, GPS drift and setup time dominate.
    static let maximumContinuousInterval: TimeInterval = 15
    static let maximumPlausibleSpeed = 35.0 // m/s
    static let courseSmoothingRadius: TimeInterval = 6
}

private struct WindProjectedPoint {
    let x: Double
    let y: Double
}

private struct WindRouteInterval {
    let startIndex: Int
    let endIndex: Int
    let midpoint: Date
    let duration: TimeInterval
    let distance: Double
    let dx: Double
    let dy: Double
    var speed: Double
    let isGap: Bool
    var courseDX: Double
    var courseDY: Double
}

private enum WindRouteCategory: Equatable {
    case idle
    case upwind
    case downwind
}

private struct WindRouteLeg {
    let category: WindRouteCategory
    let duration: TimeInterval
    let distance: Double
    let dx: Double
    let dy: Double
    let start: Date
    let end: Date
    let startLocationIndex: Int
    let endLocationIndex: Int
}

private struct WindFittedLegLine {
    let anchorX: Double
    let anchorY: Double
    let unitX: Double
    let unitY: Double
}

private func windProjectedPoint(for location: LocationData, referenceLatitude: Double) -> WindProjectedPoint {
    let latitudeRadians = location.latitude * .pi / 180
    let longitudeRadians = location.longitude * .pi / 180
    return WindProjectedPoint(
        x: WindRouteConstants.earthRadius * longitudeRadians * cos(referenceLatitude * .pi / 180),
        y: WindRouteConstants.earthRadius * latitudeRadians
    )
}

private func windWeightedMedian(_ values: [(value: Double, weight: Double)]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted { $0.value < $1.value }
    let halfWeight = sorted.reduce(0) { $0 + $1.weight } / 2
    var accumulatedWeight = 0.0
    for item in sorted {
        accumulatedWeight += item.weight
        if accumulatedWeight >= halfWeight {
            return item.value
        }
    }
    return sorted.last?.value
}

private struct WindHeadingSample {
    let intervalIndex: Int
    let x: Double
    let y: Double
    let pathToChord: Double
    let weight: Double
}

private struct WindHeadingModeAnalysis {
    let upwindByInterval: [Bool]
    let upwindSideByInterval: [Int]
    let confidence: Double
}

/// A route may contain two straight upwind tack headings and one broad, wavy
/// downwind heading. Unlike a sign test against the route's PCA axis, this can
/// recognize a tack that travels almost across that axis.
private func windHeadingModes(in intervals: [WindRouteInterval]) -> WindHeadingModeAnalysis? {
    let radius: TimeInterval = 15
    var samples = [WindHeadingSample]()
    var samplesByInterval = [WindHeadingSample?](repeating: nil, count: intervals.count)

    for index in intervals.indices {
        let interval = intervals[index]
        guard !interval.isGap, interval.speed >= WindRouteConstants.idleSpeed else { continue }
        let lowerTime = interval.midpoint.addingTimeInterval(-radius)
        let upperTime = interval.midpoint.addingTimeInterval(radius)
        var lower = index
        var upper = index
        while lower > intervals.startIndex, intervals[lower - 1].midpoint >= lowerTime {
            lower -= 1
        }
        while upper + 1 < intervals.endIndex, intervals[upper + 1].midpoint <= upperTime {
            upper += 1
        }
        let window = intervals[lower...upper]
        guard !window.contains(where: \.isGap),
              intervals[upper].midpoint.timeIntervalSince(intervals[lower].midpoint) >= 20 else {
            continue
        }
        let dx = window.reduce(0) { $0 + $1.dx }
        let dy = window.reduce(0) { $0 + $1.dy }
        let chord = hypot(dx, dy)
        guard chord >= 40 else { continue }
        let path = window.reduce(0) { $0 + $1.distance }
        let sample = WindHeadingSample(
            intervalIndex: index,
            x: dx / chord,
            y: dy / chord,
            pathToChord: path / chord,
            weight: min(interval.duration, 3)
        )
        samples.append(sample)
        samplesByInterval[index] = sample
    }
    guard samples.count >= 120 else { return nil }

    // Seed three circular course modes from populated 10-degree bins, then fit
    // their mean headings. Binning only chooses starting points; each GPS window
    // contributes its actual course to the fit.
    let binCount = 36
    let binWidth = 2 * Double.pi / Double(binCount)
    let binCenters = (0..<binCount).map { bin -> (x: Double, y: Double) in
        let angle = (Double(bin) + 0.5) * binWidth
        return (sin(angle), cos(angle))
    }
    var binWeights = [Double](repeating: 0, count: binCount)
    for sample in samples {
        let angle = (atan2(sample.x, sample.y) + 2 * .pi)
            .truncatingRemainder(dividingBy: 2 * .pi)
        let bin = min(binCount - 1, Int(angle / binWidth))
        binWeights[bin] += sample.weight
    }
    var seedIndices = [Int]()
    for _ in 0..<3 {
        var bestBin: Int?
        var bestScore = 0.0
        for bin in 0..<binCount where binWeights[bin] > 0 {
            let separation = seedIndices.map {
                windHeadingSeparation(binCenters[bin], binCenters[$0])
            }.min() ?? .pi
            let score = binWeights[bin] * separation * separation
            if score > bestScore {
                bestScore = score
                bestBin = bin
            }
        }
        guard let bestBin, !seedIndices.contains(bestBin) else { return nil }
        seedIndices.append(bestBin)
    }

    var centers = seedIndices.map { binCenters[$0] }
    for _ in 0..<12 {
        var sumsX = [Double](repeating: 0, count: 3)
        var sumsY = [Double](repeating: 0, count: 3)
        for sample in samples {
            let mode = windNearestHeadingMode(x: sample.x, y: sample.y, centers: centers)
            sumsX[mode] += sample.x * sample.weight
            sumsY[mode] += sample.y * sample.weight
        }
        for mode in 0..<3 {
            let length = hypot(sumsX[mode], sumsY[mode])
            guard length > 0 else { return nil }
            centers[mode] = (sumsX[mode] / length, sumsY[mode] / length)
        }
    }

    var waveValues = [[(value: Double, weight: Double)]](repeating: [], count: 3)
    var modeWeights = [Double](repeating: 0, count: 3)
    for sample in samples {
        let mode = windNearestHeadingMode(x: sample.x, y: sample.y, centers: centers)
        waveValues[mode].append((sample.pathToChord, sample.weight))
        modeWeights[mode] += sample.weight
    }
    let totalWeight = modeWeights.reduce(0, +)
    guard modeWeights.allSatisfy({ $0 >= max(90, totalWeight * 0.10) }) else { return nil }
    let typicalWaveiness = waveValues.compactMap(windWeightedMedian)
    guard typicalWaveiness.count == 3,
          let downwindMode = typicalWaveiness.indices.max(by: {
              typicalWaveiness[$0] < typicalWaveiness[$1]
          }) else { return nil }
    let upwindModes = (0..<3).filter { $0 != downwindMode }
    let otherWaveiness = upwindModes.map { typicalWaveiness[$0] }
    let waveinessGap = typicalWaveiness[downwindMode] - (otherWaveiness.max() ?? 0)
    guard typicalWaveiness[downwindMode] >= 1.10,
          waveinessGap >= 0.08,
          abs(otherWaveiness[0] - otherWaveiness[1]) <= 0.07 else {
        return nil
    }

    let tackSeparation = windHeadingSeparation(centers[upwindModes[0]], centers[upwindModes[1]])
    let windwardX = centers[upwindModes[0]].x + centers[upwindModes[1]].x
    let windwardY = centers[upwindModes[0]].y + centers[upwindModes[1]].y
    let windwardLength = hypot(windwardX, windwardY)
    guard (45 * .pi / 180)...(145 * .pi / 180) ~= tackSeparation,
          windwardLength > 0 else { return nil }
    let leeward = (x: -windwardX / windwardLength, y: -windwardY / windwardLength)
    guard windHeadingSeparation(centers[downwindMode], leeward) <= 65 * .pi / 180 else {
        return nil
    }

    var stableRuns = [(mode: Int, start: Int, end: Int, weight: Double)]()
    for sample in samples {
        let mode = windNearestHeadingMode(x: sample.x, y: sample.y, centers: centers)
        if let last = stableRuns.last,
           last.mode == mode,
           sample.intervalIndex - last.end <= 3 {
            stableRuns[stableRuns.count - 1].end = sample.intervalIndex
            stableRuns[stableRuns.count - 1].weight += sample.weight
        } else {
            stableRuns.append((mode, sample.intervalIndex, sample.intervalIndex, sample.weight))
        }
    }
    let sustainedRuns = stableRuns.filter { $0.weight >= 15 }
    var tackModeTransitions = 0
    for index in 1..<sustainedRuns.count {
        let previous = sustainedRuns[index - 1]
        let current = sustainedRuns[index]
        guard upwindModes.contains(previous.mode),
              upwindModes.contains(current.mode),
              previous.mode != current.mode,
              intervals[current.start].midpoint.timeIntervalSince(intervals[previous.end].midpoint) <= 60 else {
            continue
        }
        tackModeTransitions += 1
    }
    guard tackModeTransitions >= 2 else { return nil }

    var upwindByInterval = [Bool](repeating: false, count: intervals.count)
    var upwindSideByInterval = [Int](repeating: 0, count: intervals.count)
    for index in intervals.indices {
        let heading: (x: Double, y: Double)
        if let sample = samplesByInterval[index] {
            heading = (sample.x, sample.y)
        } else {
            let dx = intervals[index].courseDX
            let dy = intervals[index].courseDY
            let length = hypot(dx, dy)
            heading = length > 0 ? (dx / length, dy / length) : centers[downwindMode]
        }
        let mode = windNearestHeadingMode(
            x: heading.x,
            y: heading.y,
            centers: centers
        )
        upwindByInterval[index] = mode != downwindMode
        if let upwindIndex = upwindModes.firstIndex(of: mode) {
            upwindSideByInterval[index] = upwindIndex == 0 ? -1 : 1
        }
    }
    return WindHeadingModeAnalysis(
        upwindByInterval: upwindByInterval,
        upwindSideByInterval: upwindSideByInterval,
        confidence: min(0.95, 0.55 + waveinessGap * 2)
    )
}

private func windNearestHeadingMode(
    x: Double,
    y: Double,
    centers: [(x: Double, y: Double)]
) -> Int {
    centers.indices.max(by: {
        x * centers[$0].x + y * centers[$0].y
            < x * centers[$1].x + y * centers[$1].y
    }) ?? 0
}

private func windHeadingSeparation(
    _ first: (x: Double, y: Double),
    _ second: (x: Double, y: Double)
) -> Double {
    acos(min(1, max(-1, first.x * second.x + first.y * second.y)))
}

private func windStabilizedCategories(
    _ original: [WindRouteCategory],
    intervals: [WindRouteInterval],
    axisX: Double,
    axisY: Double
) -> [WindRouteCategory] {
    var result = original
    guard result.count == intervals.count else { return result }

    for _ in 0..<2 {
        var runs = [(start: Int, end: Int, category: WindRouteCategory)]()
        var start = 0
        while start < result.count {
            var end = start
            while end + 1 < result.count, result[end + 1] == result[start] {
                end += 1
            }
            runs.append((start, end, result[start]))
            start = end + 1
        }

        for runIndex in runs.indices {
            let run = runs[runIndex]
            guard run.category != .idle,
                  let previousRunIndex = windPreviousMovingRunIndex(before: runIndex, in: runs),
                  let nextRunIndex = windNextMovingRunIndex(after: runIndex, in: runs),
                  runs[previousRunIndex].category == runs[nextRunIndex].category,
                  runs[previousRunIndex].category != run.category else {
                continue
            }
            let distance = intervals[run.start...run.end].reduce(0) { $0 + $1.distance }
            let duration = intervals[run.start...run.end].reduce(0) { $0 + $1.duration }
            let runDX = intervals[run.start...run.end].reduce(0) { $0 + $1.dx }
            let runDY = intervals[run.start...run.end].reduce(0) { $0 + $1.dy }
            let netDistance = hypot(runDX, runDY)
            let crossFraction = abs(-runDX * axisY + runDY * axisX) / max(netDistance, 0.1)
            let surroundingCategory = runs[previousRunIndex].category
            let isShortDownwindInsideUpwind = run.category == .downwind
                && surroundingCategory == .upwind
                && distance < 10
            let isShortUpwindInsideDownwind = run.category == .upwind
                && surroundingCategory == .downwind
                && (distance < 50 || (duration < 30 && distance < 160 && crossFraction < 0.25))
            if isShortDownwindInsideUpwind || isShortUpwindInsideDownwind {
                for index in run.start...run.end {
                    result[index] = surroundingCategory
                }
            }
        }
    }
    return result
}

private func windPreviousMovingRunIndex(
    before index: Int,
    in runs: [(start: Int, end: Int, category: WindRouteCategory)]
) -> Int? {
    guard index > runs.startIndex else { return nil }
    for candidate in stride(from: index - 1, through: runs.startIndex, by: -1)
        where runs[candidate].category != .idle {
        return candidate
    }
    return nil
}

private func windNextMovingRunIndex(
    after index: Int,
    in runs: [(start: Int, end: Int, category: WindRouteCategory)]
) -> Int? {
    guard index + 1 < runs.endIndex else { return nil }
    for candidate in (index + 1)..<runs.endIndex where runs[candidate].category != .idle {
        return candidate
    }
    return nil
}

private func windMapSegments(
    locations: [LocationData],
    intervals: [WindRouteInterval],
    categories: [WindRouteCategory]
) -> [WindRouteMapSegment] {
    guard intervals.count == categories.count, !intervals.isEmpty else { return [] }
    var segments = [WindRouteMapSegment]()
    var runStart = 0

    while runStart < categories.count {
        var runEnd = runStart
        while runEnd + 1 < categories.count, categories[runEnd + 1] == categories[runStart] {
            runEnd += 1
        }

        let startIndex = intervals[runStart].startIndex
        let endIndex = intervals[runEnd].endIndex
        if startIndex >= 0, endIndex < locations.count, startIndex < endIndex {
            let fullCoordinates = locations[startIndex...endIndex].map(windCoordinate)
            let coordinates = windDownsampledCoordinates(fullCoordinates, maximumCount: 400)
            let direction: WindRouteDirection
            switch categories[runStart] {
            case .upwind: direction = .upwind
            case .downwind: direction = .downwind
            case .idle: direction = .idle
            }
            segments.append(
                WindRouteMapSegment(
                    id: segments.count,
                    direction: direction,
                    coordinates: coordinates
                )
            )
        }
        runStart = runEnd + 1
    }
    return segments
}

private func windDownsampledCoordinates(
    _ coordinates: [WindRouteCoordinate],
    maximumCount: Int
) -> [WindRouteCoordinate] {
    guard coordinates.count > maximumCount, maximumCount > 2 else { return coordinates }
    let step = max(1, Int(ceil(Double(coordinates.count - 1) / Double(maximumCount - 1))))
    var result = stride(from: 0, to: coordinates.count, by: step).map { coordinates[$0] }
    if result.last != coordinates.last, let last = coordinates.last {
        result.append(last)
    }
    return result
}

private func windTurnAngles(
    locations: [LocationData],
    projected: [WindProjectedPoint],
    intervals: [WindRouteInterval],
    categories: [WindRouteCategory],
    axisX: Double,
    axisY: Double,
    upwindSides: [Int]? = nil
) -> (angles: [Double], markers: [WindRouteAngleMarker], upwindLocationRanges: [ClosedRange<Int>]) {
    guard intervals.count == categories.count,
          locations.count == projected.count else { return ([], [], []) }
    var legs = [WindRouteLeg]()
    var currentCategory: WindRouteCategory?
    var currentSide = 0
    var duration = 0.0
    var distance = 0.0
    var dx = 0.0
    var dy = 0.0
    var startDate: Date?
    var endDate: Date?
    var startLocationIndex: Int?
    var endLocationIndex: Int?

    func appendCurrentLeg() {
        guard let category = currentCategory,
              category == .upwind,
              let startDate,
              let endDate,
              let startLocationIndex,
              let endLocationIndex else {
            return
        }
        let netDistance = hypot(dx, dy)
        let straightness = netDistance / max(distance, 0.1)
        let isRegularLeg = duration >= 15
            && distance >= 60
            && netDistance >= 45
            && straightness >= 0.80
        guard isRegularLeg else {
            return
        }
        legs.append(
            WindRouteLeg(
                category: category,
                duration: duration,
                distance: distance,
                dx: dx,
                dy: dy,
                start: startDate,
                end: endDate,
                startLocationIndex: startLocationIndex,
                endLocationIndex: endLocationIndex
            )
        )
    }

    func reset() {
        currentCategory = nil
        currentSide = 0
        duration = 0
        distance = 0
        dx = 0
        dy = 0
        startDate = nil
        endDate = nil
        startLocationIndex = nil
        endLocationIndex = nil
    }

    for index in intervals.indices {
        let interval = intervals[index]
        let category = categories[index]
        let side: Int
        if let upwindSides, upwindSides.count == intervals.count {
            side = upwindSides[index] == 0 ? currentSide : upwindSides[index]
        } else {
            let courseLength = hypot(interval.courseDX, interval.courseDY)
            let crossFraction = courseLength > 0
                ? (-interval.courseDX * axisY + interval.courseDY * axisX) / courseLength
                : 0
            side = abs(crossFraction) >= 0.12 ? (crossFraction > 0 ? 1 : -1) : currentSide
        }

        if category == .idle {
            appendCurrentLeg()
            reset()
            continue
        }

        if currentCategory != category || (currentSide != 0 && side != 0 && currentSide != side) {
            appendCurrentLeg()
            reset()
            currentCategory = category
            currentSide = side
            startDate = interval.midpoint.addingTimeInterval(-interval.duration / 2)
            startLocationIndex = interval.startIndex
        }
        if currentSide == 0 && side != 0 {
            currentSide = side
        }

        duration += interval.duration
        distance += interval.distance
        dx += interval.dx
        dy += interval.dy
        endDate = interval.midpoint.addingTimeInterval(interval.duration / 2)
        endLocationIndex = interval.endIndex
    }
    appendCurrentLeg()

    guard legs.count >= 2 else { return ([], [], []) }
    let legDistances = legs.map(\.distance).sorted()
    let middle = legDistances.count / 2
    let typicalLegDistance = legDistances.count.isMultiple(of: 2)
        ? (legDistances[middle - 1] + legDistances[middle]) / 2
        : legDistances[middle]
    let prominentLegDistance = max(60, typicalLegDistance * 0.75)
    var angles = [Double]()
    var markers = [WindRouteAngleMarker]()
    var upwindLocationRanges = [ClosedRange<Int>]()
    for index in 1..<legs.count {
        let previous = legs[index - 1]
        let current = legs[index]
        let separation = current.start.timeIntervalSince(previous.end)
        let prominentPair = previous.distance >= prominentLegDistance
            && current.distance >= prominentLegDistance
        // A short tack can be a genuine pair of straight upwind legs even when
        // both are small beside the route's long legs. Require enough travel on
        // each side and a nearly continuous connection before fitting it.
        let connectedShortPair = previous.duration >= 30
            && current.duration >= 30
            && previous.distance >= 180
            && current.distance >= 180
            && separation <= 20
        guard previous.category == .upwind,
              current.category == .upwind,
              prominentPair || connectedShortPair,
              separation <= 60 else {
            continue
        }

        // The connecting turn may briefly point downwind, but a complete
        // downwind run or a recording gap does not connect two upwind legs.
        let bridge = intervals.filter {
            $0.startIndex >= previous.endLocationIndex
                && $0.endIndex <= current.startLocationIndex
        }
        let maximumBridgeDistance = prominentPair ? 150.0 : 50.0
        guard !bridge.contains(where: \.isGap),
              bridge.reduce(0, { $0 + $1.distance }) <= maximumBridgeDistance else {
            continue
        }

        // Fit an infinite line through half of every full leg, biased slightly
        // toward the turn but excluding its curved entry/exit. PCA uses all of
        // those GPS points instead of a single start/end chord, so individual
        // GPS spikes cannot offset either ray.
        guard let previousLine = windFittedLine(
            for: previous,
            distanceRange: 0.50...0.90,
            intervals: intervals,
            projected: projected
        ),
              let currentLine = windFittedLine(
                for: current,
                distanceRange: 0.10...0.55,
                intervals: intervals,
                projected: projected
              ) else {
            continue
        }
        let dot = previousLine.unitX * currentLine.unitX + previousLine.unitY * currentLine.unitY
        let headingChange = acos(min(1, max(-1, dot))) * 180 / .pi
        // The drawn rays point backward along the incoming leg and forward
        // along the outgoing leg. Their actual included angle is the supplement
        // of the travel heading change. Folding the two infinite lines to their
        // smaller intersection angle would label a 140° corner as 40°.
        let rayAngle = 180 - headingChange
        let turnLocationIndex = previous.endLocationIndex
        let rawTurnPoint = projected[turnLocationIndex]
        let incomingTurnPoint = windProjection(of: rawTurnPoint, onto: previousLine)
        let outgoingTurnPoint = windProjection(of: rawTurnPoint, onto: currentLine)
        let incomingOffset = hypot(incomingTurnPoint.x - rawTurnPoint.x, incomingTurnPoint.y - rawTurnPoint.y)
        let outgoingOffset = hypot(outgoingTurnPoint.x - rawTurnPoint.x, outgoingTurnPoint.y - rawTurnPoint.y)
        if rayAngle >= (prominentPair ? 20 : 30),
           rayAngle <= 90,
           max(incomingOffset, outgoingOffset) <= 120 {
            angles.append(rayAngle)
            let bridgeStart = min(previous.endLocationIndex, current.startLocationIndex)
            let bridgeEnd = max(previous.endLocationIndex, current.startLocationIndex)
            upwindLocationRanges.append(bridgeStart...bridgeEnd)
            let vertex = windCoordinate(locations[turnLocationIndex])
            let incomingVertex = windOffsetCoordinate(
                from: windCoordinate(locations[turnLocationIndex]),
                eastMeters: incomingTurnPoint.x - rawTurnPoint.x,
                northMeters: incomingTurnPoint.y - rawTurnPoint.y
            )
            let outgoingVertex = windOffsetCoordinate(
                from: windCoordinate(locations[turnLocationIndex]),
                eastMeters: outgoingTurnPoint.x - rawTurnPoint.x,
                northMeters: outgoingTurnPoint.y - rawTurnPoint.y
            )
            let rayLength = 120.0
            markers.append(
                WindRouteAngleMarker(
                    id: markers.count,
                    angle: rayAngle,
                    incomingPoint: windOffsetCoordinate(
                        from: incomingVertex,
                        eastMeters: -previousLine.unitX * rayLength,
                        northMeters: -previousLine.unitY * rayLength
                    ),
                    incomingTurnPoint: incomingVertex,
                    vertex: vertex,
                    outgoingTurnPoint: outgoingVertex,
                    outgoingPoint: windOffsetCoordinate(
                        from: outgoingVertex,
                        eastMeters: currentLine.unitX * rayLength,
                        northMeters: currentLine.unitY * rayLength
                    )
                )
            )
        }
    }
    return (angles, markers, upwindLocationRanges)
}

private func windFittedLine(
    for leg: WindRouteLeg,
    distanceRange: ClosedRange<Double>,
    intervals: [WindRouteInterval],
    projected: [WindProjectedPoint]
) -> WindFittedLegLine? {
    let legIntervals = intervals.filter {
        !$0.isGap
            && $0.startIndex >= leg.startLocationIndex
            && $0.endIndex <= leg.endLocationIndex
    }
    let totalDistance = legIntervals.reduce(0) { $0 + $1.distance }
    guard totalDistance > 0 else { return nil }

    let lowerDistance = totalDistance * distanceRange.lowerBound
    let upperDistance = totalDistance * distanceRange.upperBound
    var cumulativeDistance = 0.0
    var samples = [(x: Double, y: Double, weight: Double)]()

    for interval in legIntervals {
        let intervalStart = cumulativeDistance
        let intervalEnd = cumulativeDistance + interval.distance
        let overlap = max(0, min(intervalEnd, upperDistance) - max(intervalStart, lowerDistance))
        if overlap > 0, interval.distance > 0 {
            let start = projected[interval.startIndex]
            let end = projected[interval.endIndex]
            samples.append(((start.x + end.x) / 2, (start.y + end.y) / 2, overlap))
        }
        cumulativeDistance = intervalEnd
        if cumulativeDistance >= upperDistance { break }
    }

    let totalWeight = samples.reduce(0) { $0 + $1.weight }
    guard samples.count >= 2, totalWeight > 0 else { return nil }
    let meanX = samples.reduce(0) { $0 + $1.x * $1.weight } / totalWeight
    let meanY = samples.reduce(0) { $0 + $1.y * $1.weight } / totalWeight
    let covarianceXX = samples.reduce(0) { $0 + pow($1.x - meanX, 2) * $1.weight } / totalWeight
    let covarianceXY = samples.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) * $1.weight } / totalWeight
    let covarianceYY = samples.reduce(0) { $0 + pow($1.y - meanY, 2) * $1.weight } / totalWeight
    let angle = 0.5 * atan2(2 * covarianceXY, covarianceXX - covarianceYY)
    var unitX = cos(angle)
    var unitY = sin(angle)
    if unitX * leg.dx + unitY * leg.dy < 0 {
        unitX = -unitX
        unitY = -unitY
    }
    return WindFittedLegLine(anchorX: meanX, anchorY: meanY, unitX: unitX, unitY: unitY)
}

private func windProjection(
    of point: WindProjectedPoint,
    onto line: WindFittedLegLine
) -> (x: Double, y: Double) {
    let offsetX = point.x - line.anchorX
    let offsetY = point.y - line.anchorY
    let scale = offsetX * line.unitX + offsetY * line.unitY
    return (
        line.anchorX + scale * line.unitX,
        line.anchorY + scale * line.unitY
    )
}

private func windCoordinate(_ location: LocationData) -> WindRouteCoordinate {
    WindRouteCoordinate(latitude: location.latitude, longitude: location.longitude)
}

private func windOffsetCoordinate(
    from start: WindRouteCoordinate,
    eastMeters: Double,
    northMeters: Double
) -> WindRouteCoordinate {
    return WindRouteCoordinate(
        latitude: start.latitude + northMeters / 111_111,
        longitude: start.longitude + eastMeters / (111_111 * cos(start.latitude * .pi / 180))
    )
}
