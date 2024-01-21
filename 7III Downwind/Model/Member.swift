//
//  Member.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import Foundation

struct Member: Identifiable, Codable, Hashable {
    var id: UUID?
    var name: String
    var status: String?
    
    var latitude: Double?
    var longitude: Double?
    
    // speed in km/h
    var speed: Double?
    
    var onlyWatching: Bool?
    
    var createdOn: String?
    
    var lastUpdated: String?
}
