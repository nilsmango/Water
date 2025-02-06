//
//  HelperFunctions.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation
import SwiftUI

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
