//
//  LocationHelperFunctions.swift
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

/// Takes coordinates in degrees and returns direct distance in meters
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

/// Takes a distance in m and gives us back a string of the distance that looks great with km or m.
func makePrettyDistance(meters: Double) -> String {
    if meters >= 1000.0 {
        let km = meters / 1000
        let rounded = Int(km.rounded())
        let string = "\(rounded) km"
        return string
        
    } else {
        let rounded = Int(meters.rounded())
        let string = "\(rounded) m"
        return string
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
func calculateBearing(sourceLatitude: Double, sourceLongitude: Double, targetLatitude: Double, targetLongitude: Double) -> Double {
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
func calculateRelativeBearing(myTrueHeading: Double, bearing: Double) -> Double {
    return (bearing - myTrueHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
}
