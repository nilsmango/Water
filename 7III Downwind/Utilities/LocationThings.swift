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
    return timeElapsed > 0 ? distance / timeElapsed : nil
}

/// returns how many times you got below 8 km/h (not counting the first non flight and the last (falls)), and also the % of not flying.
func calculateNonFoilStats(from data: [LocationData], thresholdSpeedKmh: Double = 8.0) -> (nonFoilCount: Int, nonFoilPercentage: Double) {
    guard data.count > 1 else { return (0, 0.0) }
    
    let thresholdSpeedMs = thresholdSpeedKmh / 3.6
    var nonFoilCount = 0
    var nonFoilDuration: TimeInterval = 0
    let totalDuration = data.last!.timestamp.timeIntervalSince(data.first!.timestamp)
    
    var isNonFoil = false
    var periodStart: Date?
    var firstMovementDetected = false

    for i in 1..<data.count {
        let speed = calculateSpeed(in: data, fromIndex: i - 1, duration: 1) ?? 0
        
        if speed >= thresholdSpeedMs {
            firstMovementDetected = true
            if isNonFoil {
                isNonFoil = false
                if let start = periodStart {
                    nonFoilDuration += data[i - 1].timestamp.timeIntervalSince(start)
                    nonFoilCount += 1
                }
            }
        } else if firstMovementDetected {
            if !isNonFoil {
                isNonFoil = true
                periodStart = data[i - 1].timestamp
            }
        }
    }
    
    // Add final non-foil duration if it didn't end moving
    if isNonFoil {
        // Don't count non-foil at the end
        if nonFoilCount > 0 {
            nonFoilCount -= 1
        }
    }
    
    let nonFoilPercentage = (nonFoilDuration / totalDuration) * 100
    return (nonFoilCount, nonFoilPercentage)
}

