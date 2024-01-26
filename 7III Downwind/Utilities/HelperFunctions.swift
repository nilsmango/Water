//
//  HelperFunctions.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation


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
