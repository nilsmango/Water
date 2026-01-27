//
//  LocationThings.swift
//  7III Downwind
//
//  Created by Simon Lang on 01.01.24.
//

import CoreLocation

/// Takes coordinates in degrees and return latitude, longitude and direct distance in meter
func calculateDistances(fromLatitude: Double, fromLongitude: Double, toLatitude: Double, toLongitude: Double) -> (latitudeDistance: CLLocationDistance, longitudeDistance: CLLocationDistance, directDistance: CLLocationDistance) {
    let fromLocation = CLLocation(latitude: fromLatitude, longitude: fromLongitude)
    let toLocation = CLLocation(latitude: toLatitude, longitude: toLongitude)
    
    let latitudeDistance = fromLocation.distance(from: CLLocation(latitude: toLatitude, longitude: fromLongitude))
    let longitudeDistance = fromLocation.distance(from: CLLocation(latitude: fromLatitude, longitude: toLongitude))
    let directDistance = fromLocation.distance(from: toLocation)
    
    return (latitudeDistance, longitudeDistance, directDistance)
}

/// Takes two members and returns direct distance in meters
func calculateDirectDistance(from myself: Member, to member: Member) -> CLLocationDistance? {
    // Check if any of the coordinates is nil
    guard let myLatitude = myself.latitude,
          let myLongitude = myself.longitude,
          let memberLatitude = member.latitude,
          let memberLongitude = member.longitude else {
        return nil
    }

    let fromLocation = CLLocation(latitude: myLatitude, longitude: myLongitude)
    let toLocation = CLLocation(latitude: memberLatitude, longitude: memberLongitude)

    let directDistance = fromLocation.distance(from: toLocation)

    return directDistance
}


private let metersPerYard = 0.9144
private let yardsPerMile = 1760.0
private let metersPerMile = 1609.344

/// Takes a distance in m and gives us back a string of the distance that looks great with km or m or mi or yd.
func makePrettyDistance(meters: Double, system: MeasurementSystem, statistics: Bool = false) -> String {
    switch system {
    case .metric:
        if meters >= 1000.0 {
            let km = meters / 1000
            let kilometer: String
            if km >= 100 || !statistics {
                kilometer = formatWithSeparator(Int(km.rounded()), separator: "'")
            } else {
                // rounding to two decimals
                let rounded = (km * 100).rounded() / 100
                let parts = String(format: "%.2f", rounded).split(separator: ".")
                let formatted = formatWithSeparator(Int(parts[0]) ?? 0, separator: "'")
                kilometer = "\(formatted).\(parts[1])"
            }
            let string = "\(kilometer) km"
            return string
            
        } else {
            if meters.isNaN || meters.isInfinite {
                return ""
            } else {
                let rounded = Int(meters.rounded())
                let string = "\(rounded) m"
                return string
            }
        }
    case .imperial:
        // get yards
        let yards = meters / metersPerYard
        
        if yards >= yardsPerMile {
            let miles = yards / yardsPerMile
            let roundedMiles = Int(miles.rounded())
            let string = "\(formatWithSeparator(roundedMiles, separator: ",") ) mi"
            return string
            
        } else {
            if yards.isNaN || yards.isInfinite {
                return ""
            } else {
                let roundedYards = Int(yards.rounded())
                let string = "\(roundedYards) yd"
                return string
            }
        }
    }
}

private func formatWithSeparator(_ number: Int, separator: String) -> String {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = separator
    numberFormatter.numberStyle = .decimal
    return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

/// Takes a speed in km/h, returns a pretty speed in km/h or mph
func makePrettySpeed(speed: Double?, system: MeasurementSystem) -> String {
    if speed == nil || speed!.isNaN || speed!.isInfinite || speed == 0.0 {
        return "0.0 km/h"
    }
    switch system {
    case .metric:
        if speed! >= 10.0 {
            return String(Int(speed!.rounded())) + " km/h"
        } else {
            return String(format: "%.1f", speed!) + " km/h"
        }
        
    case .imperial:
        let mph = speed! * 1000 / metersPerMile
        
        if mph >= 10.0 {
            return String(Int(mph.rounded())) + " mph"
        } else {
            return String(format: "%.1f", mph) + " mph"
        }
    }
    
}

/// Takes a time in minutes, returns a pretty time in d, h, min, s
func makePrettyTime(timeInMinutes: Double) -> String {
    if timeInMinutes >= 1440.0 { // 1440 minutes in a day
        let totalMinutes = Int(timeInMinutes.rounded())
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let remainingMinutes = totalMinutes % 60
        var result = "\(days) d"
        if hours > 0 {
            result += " \(hours) h"
        }
        if remainingMinutes > 0 {
            result += " \(remainingMinutes) min"
        }
        return result
    } else if timeInMinutes >= 60.0 {
        let totalMinutes = Int(timeInMinutes.rounded())
        let hours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        if remainingMinutes > 0 {
            return "\(hours) h \(remainingMinutes) min"
        } else {
            return "\(hours) h"
        }
    } else {
        let minutes = Int(timeInMinutes)
        let seconds = Int((timeInMinutes - Double(minutes)) * 60)
        if seconds == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes) min \(seconds) s"
        }
    }
}

func makeShortName(name: String) -> String {
    let words = name.components(separatedBy: " ")
    
    if words.count == 1 {
        // Single-word name, use the first two letters
        let shortName = String(words[0].prefix(2)).uppercased()
        return shortName
    } else if words.count >= 2 {
        // Two or more words, use the first letter of the first word and the first letter of the second word
        let firstLetter = String(words[0].prefix(1)).uppercased()
        let secondLetter = String(words[1].prefix(1)).uppercased()
        return firstLetter + secondLetter
    } else {
        // No words provided
        return ""
    }
}


/// Calculating relative position to start position of member
func calculateMemberRunData(of member: Member, to startPos: Member) -> MemberRunData {
    let distances = calculateDistances(fromLatitude: startPos.latitude!, fromLongitude: startPos.longitude!, toLatitude: member.latitude!, toLongitude: member.longitude!)
        
    return MemberRunData(x: distances.latitudeDistance, y: distances.longitudeDistance, distance: distances.directDistance)
}



/// calculating if the relativPos is inside the canvas
func isPosInside(position: MemberRunData, canvasWidth: Double, canvasHeight: Double) -> Bool {
    if (-canvasWidth / 2 ... canvasWidth / 2).contains(position.x) && (-canvasHeight / 2 ... canvasHeight / 2).contains(position.y) {
        return true
    } else {
        return false
    }
}

/// calculating bearing of two locations
private func calculateBearing(sourceLatitude: Double, sourceLongitude: Double, targetLatitude: Double, targetLongitude: Double) -> Double {
    let lat1 = sourceLatitude.degreesToRadians
    let lon1 = sourceLongitude.degreesToRadians
    let lat2 = targetLatitude.degreesToRadians
    let lon2 = targetLongitude.degreesToRadians

    let dLon = lon2 - lon1

    let x = sin(dLon) * cos(lat2)
    let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

    let bearing = atan2(x, y).radiansToDegrees
    return (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
}

/// calculating the relative bearing
private func calculateRelativeBearing(myTrueHeading: Double, bearing: Double) -> Double {
    return (bearing - myTrueHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
}

/// calculating the relative bearing from heading and locations, returns heading in degrees (0 == north)
func calculateBearingToTarget(myTrueHeading: Double, myLatitude: Double, myLongitude: Double, targetLatitude: Double, targetLongitude: Double) -> Double {
    let bearing = calculateBearing(sourceLatitude: myLatitude, sourceLongitude: myLongitude, targetLatitude: targetLatitude, targetLongitude: targetLongitude)
    let relativeBearing = calculateRelativeBearing(myTrueHeading: myTrueHeading, bearing: bearing)
    
    return relativeBearing
}

enum LocationError {
    case none, noPermission, notPossible
}

/// returns 1 sec and 10 sec top speeds in km/h from an array of LocationData
func calculateTopSpeeds(from data: [LocationData]) -> (topSpeed1Sec: Double?, topSpeed10Sec: Double?) {
    var topSpeed1Sec: Double = 0
    var topSpeed10Sec: Double = 0
    
    for i in 0..<data.count {
        // 1-second window
        if let oneSecSpeed = calculateSpeed(in: data, fromIndex: i, duration: 1) {
            topSpeed1Sec = max(topSpeed1Sec, oneSecSpeed)
        }
        // 10-second window
        if let tenSecSpeed = calculateSpeed(in: data, fromIndex: i, duration: 10) {
            topSpeed10Sec = max(topSpeed10Sec, tenSecSpeed)
        }
    }
    
    return (topSpeed1Sec * 3.6, topSpeed10Sec * 3.6)
}

struct FastestDistanceResult {
    let distanceLabel: String
    let timeString: String
    let speedString: String
    let rawSpeed: Double
}

/// returns formatted string of fastest km time in minutes:seconds with start position in km, or nil if not found
func calculateFastestKm(from data: [LocationData]) -> String? {
    var fastestKmSeconds: Double = Double.infinity
    var fastestKmStartIndex = 0
    
    for i in 0..<data.count {
        if let (kmTime, _) = calculateFastestDistance(in: data, fromIndex: i, targetDistance: 1000.0) {
            if kmTime < fastestKmSeconds {
                fastestKmSeconds = kmTime
                fastestKmStartIndex = i
            }
        }
    }
    
    if fastestKmSeconds == Double.infinity {
        return nil
    }
    
    let cumulativeDistances = calculateCumulativeDistances(from: data)
    let startKm = cumulativeDistances[fastestKmStartIndex] / 1000
    
    let minutes = Int(fastestKmSeconds) / 60
    let seconds = Int(fastestKmSeconds.rounded()) % 60
    
    return "\(minutes):\(String(format: "%02d", seconds)) (km: \(String(format: "%.2f", startKm)))"
}

/// returns array of fastest distances (50m, 100m, 1km) with time and speed strings
func calculateFastestDistances(from data: [LocationData], system: MeasurementSystem) -> [FastestDistanceResult] {
    var results: [FastestDistanceResult] = []
    let distancesToCheck = [(50.0, "50 m"), (100.0, "100 m"), (1000.0, "1 km")]
    
    for (distanceInMeters, label) in distancesToCheck {
        var fastestSeconds: Double = Double.infinity
        var fastestStartIndex = 0
        
        for i in 0..<data.count {
            if let (time, _) = calculateFastestDistance(in: data, fromIndex: i, targetDistance: distanceInMeters) {
                if time < fastestSeconds {
                    fastestSeconds = time
                    fastestStartIndex = i
                }
            }
        }
        
        if fastestSeconds != Double.infinity {
            let cumulativeDistances = calculateCumulativeDistances(from: data)
            _ = cumulativeDistances[fastestStartIndex] / 1000
            
            let distanceInKm = distanceInMeters / 1000.0
            let rawSpeed = distanceInKm / (fastestSeconds / 3600.0)
            
            let timeString: String
            if distanceInMeters == 1000.0 {
                let minutes = Int(fastestSeconds) / 60
                let seconds = Int(fastestSeconds.rounded()) % 60
                timeString = "\(minutes):\(String(format: "%02d", seconds)) min"
            } else {
                timeString = String(format: "%.1f s", fastestSeconds)
            }
            
            let speedString = makePrettySpeed(speed: rawSpeed, system: system)
            
            results.append(FastestDistanceResult(
                distanceLabel: label,
                timeString: timeString,
                speedString: speedString,
                rawSpeed: rawSpeed
            ))
        }
    }
    
    return results
}

private func calculateSpeed(in data: [LocationData], fromIndex index: Int, duration: TimeInterval) -> Double? {
    let start = data[index]
    let endTime = start.timestamp.addingTimeInterval(duration)
    
    var distance: Double = 0
    var lastPoint = start
    
    for i in index+1..<data.count {
        let point = data[i]
        if point.timestamp > endTime { break }
        
        let fromLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
        let toLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
        
        distance += fromLocation.distance(from: toLocation)
        lastPoint = point
    }
    
    let timeElapsed = lastPoint.timestamp.timeIntervalSince(start.timestamp)
    
    // Using all speeds that are within a 2% window
    return timeElapsed >= duration * 0.98 ? distance / timeElapsed : nil
}

private func calculateFastestDistance(in data: [LocationData], fromIndex index: Int, targetDistance: Double) -> (Double, Int)? {
    let start = data[index]
    var distance: Double = 0
    var lastPoint = start
    
    for i in index+1..<data.count {
        let point = data[i]
        
        let fromLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
        let toLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
        
        distance += fromLocation.distance(from: toLocation)
        lastPoint = point
        
        // Accept distances within 1.5% tolerance of target
        if distance >= targetDistance * 0.985 {
            let timeElapsed = lastPoint.timestamp.timeIntervalSince(start.timestamp)
            
            return (timeElapsed, i)
        }
    }
    
    return nil
}

private func calculateCumulativeDistances(from data: [LocationData]) -> [Double] {
    var cumulativeDistances = [Double](repeating: 0.0, count: data.count)
    
    guard data.count > 0 else { return cumulativeDistances }
    
    for i in 1..<data.count {
        let fromLocation = CLLocation(latitude: data[i-1].latitude, longitude: data[i-1].longitude)
        let toLocation = CLLocation(latitude: data[i].latitude, longitude: data[i].longitude)
        let distance = fromLocation.distance(from: toLocation)
        cumulativeDistances[i] = cumulativeDistances[i-1] + distance
    }
    
    return cumulativeDistances
}

private enum TurnDirection {
    case left, right
}

private func averageBearing(from data: [LocationData], currentIndex: Int, windowSize: Int) -> Double {
    var sum: Double = 0
    for j in (currentIndex - windowSize + 1)...currentIndex {
        sum += calculateBearing(
            sourceLatitude: data[j - 1].latitude,
            sourceLongitude: data[j - 1].longitude,
            targetLatitude: data[j].latitude,
            targetLongitude: data[j].longitude
        )
    }
    return sum / Double(windowSize)
}


private func bearingDifference(newBearing: Double, oldBearing: Double, oldDirection: TurnDirection?) -> TurnDirection {
    let difference = (newBearing - oldBearing).truncatingRemainder(dividingBy: 360)
    let normalizedDiff = (difference + 540).truncatingRemainder(dividingBy: 360) - 180
    
    // If difference is positive, it's a right turn
    // If difference is negative, it's a left turn
    // if no difference return old direction
    if let oldDirection = oldDirection, normalizedDiff == 0 {
        return oldDirection
    } else {
        return normalizedDiff >= 0 ? .right : .left
    }
    
}

/// returns how many times you got below threshold speed (not counting the first non flight and the last (falls)), and also the % of not flying (time) and also the longest distance on foil in n
func calculateFoilingStats(
    from data: [LocationData],
    thresholdSpeedKmh: Double = 8.0,
    countTurns: Bool = false,
    returnWaves: Bool = false
) -> (
    popUps: Int,
    timeOnFoilPercentage: Double,
    turns: Int,
    longestDistanceOnFoil: Double,
    waves: [[LocationData]]
) {
    guard data.count > 1 else {
        return (0, 0, 0, 0, [])
    }

    let indexes = findAboveThresholdIndexes(
        in: data,
        thresholdKmh: thresholdSpeedKmh
    )

    guard indexes.count >= 2 else {
        return (0, 0, 0, 0, [])
    }

    // Pop-ups = number of flight segments
    var popUps = indexes.count / 2
    if indexes.first == 0 {
        popUps = max(0, popUps - 1)
    }

    let needsSegmentData = countTurns || returnWaves
    var segments: [[LocationData]] = needsSegmentData ? [] : []

    var timeOnFoil: TimeInterval = 0
    var longestDistanceOnFoil = 0.0
    var turns = 0

    // Walk each flight segment once
    for i in stride(from: 1, to: indexes.count, by: 2) {
        let start = indexes[i - 1]
        let end = indexes[i]

        guard end > start else { continue }

        // Time
        let flightTime = data[end].timestamp.timeIntervalSince(data[start].timestamp)
        timeOnFoil += flightTime

        // Distance (single pass)
        var flightDistance = 0.0
        var segmentSlice: [LocationData]? = needsSegmentData ? [] : nil

        for j in (start + 1)...end {
            flightDistance += calculateDistances(
                fromLatitude: data[j - 1].latitude,
                fromLongitude: data[j - 1].longitude,
                toLatitude: data[j].latitude,
                toLongitude: data[j].longitude
            ).directDistance

            if needsSegmentData {
                segmentSlice?.append(data[j - 1])
            }
        }

        if needsSegmentData {
            segmentSlice?.append(data[end])
            if let segment = segmentSlice {
                segments.append(segment)

                if countTurns {
                    turns += findTurns(in: segment)
                }
            }
        }

        longestDistanceOnFoil = max(longestDistanceOnFoil, flightDistance)
    }

    // Total workout time
    let totalTime = data.last!.timestamp.timeIntervalSince(data.first!.timestamp)

    let timeOnFoilPercentage: Double
    if totalTime > 0 {
        timeOnFoilPercentage = (timeOnFoil / totalTime) * 100
    } else {
        timeOnFoilPercentage = 0
    }

    return (
        popUps,
        timeOnFoilPercentage,
        turns,
        longestDistanceOnFoil,
        returnWaves ? segments : []
    )
}


/// Returns the indexes where we go from below threshold to above and back again. Taking 6 seconds because then we are sure to fly.
private func findAboveThresholdIndexes(in data: [LocationData], thresholdKmh: Double, minimumTimeInSeconds: Double = 6) -> [Int] {
    let thresholdMs = thresholdKmh / 3.6 // Convert km/h to m/s
    var transitionIndexes: [Int] = []
    
    var currentState: Bool? = nil // true = above threshold, false = below threshold
    var potentialTransitionIndex: Int? = nil
    var potentialTransitionTime: Date? = nil
    
    for (index, location) in data.enumerated() {
        var speed: Double? = nil
        if location.speed == nil {
            if index > 0 {
                // calculate speed from last location to this location
                let lastLocation = data[index - 1]
                let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
                
                let fromLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
                let toLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

                let directDistance = fromLocation.distance(from: toLocation)
                
                speed = directDistance / timeInterval
            }
        } else {
            speed = location.speed!
        }
        let speedIsAboveThreshold = speed ?? thresholdMs + 1 > thresholdMs
        
        // init
        if currentState == nil {
            // if we are above threshold from the start we want to test, else we just start in current state
            if speedIsAboveThreshold {
                // Initial state setup to start testing if we are going steady above threshold from the start
                currentState = !speedIsAboveThreshold
                // setting first transition to start if we are above threshold
                potentialTransitionTime = location.timestamp
                potentialTransitionIndex = index
            } else {
                currentState = speedIsAboveThreshold
            }
            
            continue
        }
        
        if speedIsAboveThreshold != currentState {
            // Speed crossed the threshold, start timing the potential transition
            if potentialTransitionTime == nil {
                potentialTransitionTime = location.timestamp
                potentialTransitionIndex = index
            }
            // Check if we've been on the new side for more than min time
            if let startTime = potentialTransitionTime,
               location.timestamp.timeIntervalSince(startTime) >= minimumTimeInSeconds {
                // Record the first index of the transition
                if let validIndex = potentialTransitionIndex {
                    transitionIndexes.append(validIndex)
                }
                // Update current state to reflect the transition
                currentState = speedIsAboveThreshold
                potentialTransitionTime = nil
                potentialTransitionIndex = nil
            }
        } else {
            // Speed reverted back before completing the transition time, reset potential transition
            potentialTransitionTime = nil
            potentialTransitionIndex = nil
        }
    }
    
    if transitionIndexes.count % 2 != 0 {
        let lastIndex = data.count - 1
        transitionIndexes.append(lastIndex)
    }
    
    return transitionIndexes
}


/// finds the number of turns in a given run
private func findTurns(in data: [LocationData], smoothingValue: Int = 2) -> Int {
    var currentHeading: Double? = nil
    var currentDirection: TurnDirection? = nil
//    var lastTurnIndex = 0
    var potentialTurnIndex: Int? = nil
    var turnCount: Int = 0
    
    // safety
    if data.count <= 1 {
        return turnCount
    }
    
    for i in 1..<data.count {
        let sourceLocation = data[i-1]
        let targetLocation = data[i]
        let newHeading = calculateBearing(sourceLatitude: sourceLocation.latitude, sourceLongitude: sourceLocation.longitude, targetLatitude: targetLocation.latitude, targetLongitude: targetLocation.longitude)
        
        if currentHeading != nil {
            
            let newDirection = bearingDifference(newBearing: newHeading, oldBearing: currentHeading!, oldDirection: currentDirection)
            
            if currentDirection == nil {
                // init of direction
                currentDirection = newDirection
                
            } else if currentDirection != newDirection {
                // check if we have a potential index
                if potentialTurnIndex != nil {
                    // check if we are already outside the smoothing window
                    if i - potentialTurnIndex! >= smoothingValue {
                        // turn detected
                        turnCount += 1
                        potentialTurnIndex = nil
                        currentDirection = newDirection
                    }
                } else {
                    potentialTurnIndex = i
                }
                
            } else {
                // if we are not on anew direction we reset the potential turn index
                potentialTurnIndex = nil
            }
            
        }
        // update currentHeading
        currentHeading = newHeading
    }
    
    return turnCount
}
