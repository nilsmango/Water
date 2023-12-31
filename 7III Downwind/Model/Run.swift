//
//  Run.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import Foundation

// TODO: make this a observable object (members being observed)? nope?
struct Run: Identifiable, Codable {
    var id: UUID?
    
    var name: String
    
    var members: [Member]
    
    var active: Bool
}
