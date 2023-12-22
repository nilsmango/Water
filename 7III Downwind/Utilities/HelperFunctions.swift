//
//  HelperFunctions.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation

func createSongURL() throws -> URL {
    let urlString = Constants.baseURL + Endpoints.songs
    
    guard let url = URL(string: urlString) else {
        throw HTTPError.badURL
    }
    
    return url
}
