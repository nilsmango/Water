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
func makePrettyDistance(meters: Double, system: MeasurementSystem) -> String {
    switch system {
    case .metric:
        if meters >= 1000.0 {
            let km = meters / 1000
            let kilometer: String
            if km >= 100 {
                kilometer = String(Int(km.rounded()))
            } else {
                // rounding to two decimals
                let rounded = (km * 100).rounded() / 100
                kilometer = String(format: "%.2f", rounded)
            }
            let string = "\(kilometer) km"
            return string
            
        } else {
            let rounded = Int(meters.rounded())
            let string = "\(rounded) m"
            return string
        }
    case .imperial:
        // get yards
        let yards = meters / metersPerYard
        
        if yards >= yardsPerMile {
            let miles = yards / yardsPerMile
            let roundedMiles = Int(miles.rounded())
            let string = "\(roundedMiles) mi"
            return string
            
        } else {
            let roundedYards = Int(yards.rounded())
            let string = "\(roundedYards) yd"
            return string
        }
    }
    
}

/// Takes a speed in km/h, returns a pretty speed in km/h or mph
func makePrettySpeed(speed: Double, system: MeasurementSystem) -> String {
    
    switch system {
    case .metric:
        if speed.isNaN || speed.isInfinite {
            return "0.0 km/h"
        }
        if speed >= 10.0 {
            return String(Int(speed.rounded())) + " km/h"
        } else {
            return String(format: "%.1f", speed) + " km/h"
        }
    case .imperial:
        if speed.isNaN {
            return "0.0 mph"
        }
        let mph = speed * 1000 / metersPerMile
        
        if mph >= 10.0 {
            return String(Int(mph.rounded())) + " mph"
        } else {
            return String(format: "%.1f", mph) + " mph"
        }
    }
    
}

/// Takes a time in minutes, returns a pretty time in h or min
func makePrettyTime(timeInMinutes: Double) -> String {
    if timeInMinutes >= 60.0 {
        let roundedMinutes = timeInMinutes.rounded()
        let hours = Int(roundedMinutes / 60)
        let remainingMinutes = Int(roundedMinutes) % 60
        if remainingMinutes > 0 {
            return "\(hours) h \(remainingMinutes) min"
        } else {
            return "\(hours) h"
        }
        
    } else {
        let roundedMinutes = Int(timeInMinutes.rounded())
        let minutesString = String(roundedMinutes)
        return "\(minutesString) min"
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
