//
//  HelperFunctions.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation
import SwiftUI
import MapKit

func createDWURL(endpoint: String) throws -> URL {
    let urlString = Constants.baseURL + endpoint
    
    guard let url = URL(string: urlString) else {
        throw HTTPError.badURL
    }
    
    return url
}

// TODO: Remove this
func createSongURL() throws -> URL {
    let urlString = Constants.baseURL + Endpoints.songs
    
    guard let url = URL(string: urlString) else {
        throw HTTPError.badURL
    }
    
    return url
}

func dateFromString(_ dateString: String) -> Date? {
    let dateFormatter = ISO8601DateFormatter()
//    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]

    return dateFormatter.date(from: dateString)
}

/// decoding sample location data
func decodeLocationSampleData() -> [LocationData]? {
    if let url = Bundle.main.url(forResource: "locationData", withExtension: "json") {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let locations = try decoder.decode([LocationData].self, from: data)
            return locations
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    return nil
}


/// making a string work as an URL by replacing strings with %20
func replaceSpacesInString(input: String) -> String {
    return input.replacingOccurrences(of: " ", with: "%20")
}

/// creates a string from an url
func makeURLToRunName(url: URL) -> String {
    let stringFromURL = url.absoluteString
    let rawRunName = stringFromURL.replacingOccurrences(of: Constants.deepLinkBase, with: "")
    return rawRunName.replacingOccurrences(of: "%20", with: " ")
}

func makePrettyMinutesString(timeInSeconds: Double, paceFormat: Bool = false) -> String {
    if !timeInSeconds.isNaN && timeInSeconds != .infinity && timeInSeconds != -.infinity {
        let roundedTime = timeInSeconds.rounded()
        let minutes = Int(roundedTime / 60.0)
        let seconds = Int(roundedTime) % 60
        let timeInMinutesString = String(minutes)
        let additionToSeconds: String
        if seconds > 9 {
            additionToSeconds = ""
        } else {
            additionToSeconds = "0"
        }
        let dividers = paceFormat ? ("'", "\"") : (":", "")
        
        let prettyTime = timeInMinutesString + dividers.0 + additionToSeconds + String(seconds) + dividers.1
        
        return prettyTime
    } else {
        return ""
    }
}


func makeStringFromDate(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yy-MM-dd"
    return dateFormatter.string(from: date)
}

func formatActivityName(_ name: String) -> String {
    let exceptions = ["Paddling", "Wake Thief", "Sailing", "Canoe"]
    if exceptions.contains(name) {
        return name
    } else if name.hasSuffix("e") {
        return "\(name.dropLast())ing"
    } else {
        return "\(name)ing"
    }
}

func calculateAngle(from coordinates: [CLLocationCoordinate2D]) -> String {
    guard coordinates.count >= 3 else { return "N/A" }
    
    let p1 = coordinates[0]
    let vertex = coordinates[1]
    let p3 = coordinates[2]
    
    // Convert to radians for calculation
    let lat1 = p1.latitude * .pi / 180
    let lon1 = p1.longitude * .pi / 180
    let lat2 = vertex.latitude * .pi / 180
    let lon2 = vertex.longitude * .pi / 180
    let lat3 = p3.latitude * .pi / 180
    let lon3 = p3.longitude * .pi / 180
    
    // Calculate bearings from vertex to both points
    let dLon1 = lon1 - lon2
    let dLon3 = lon3 - lon2
    
    let y1 = sin(dLon1) * cos(lat1)
    let x1 = cos(lat2) * sin(lat1) - sin(lat2) * cos(lat1) * cos(dLon1)
    let bearing1 = atan2(y1, x1)
    
    let y3 = sin(dLon3) * cos(lat3)
    let x3 = cos(lat2) * sin(lat3) - sin(lat2) * cos(lat3) * cos(dLon3)
    let bearing3 = atan2(y3, x3)
    
    // Calculate angle between bearings
    var angle = bearing3 - bearing1
    
    // Normalize to 0-360 degrees
    angle = angle * 180 / .pi
    if angle < 0 {
        angle += 360
    }
    
    // Get the smaller angle (interior angle)
    if angle > 180 {
        angle = 360 - angle
    }
    
    return String(format: "%.1f°", angle)
}
