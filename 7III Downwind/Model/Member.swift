//
//  Member.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import Foundation

struct Member: Identifiable, Codable {
    let id: UUID?
    var name: String
    
    var latitude: Double?
    var longitude: Double?
    
    var onlyWatching: Bool?
    
}
