//
//  Run.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import Foundation

struct Run: Identifiable, Codable {
    var id: UUID?
    
    var name: String
    
    var members: [Member]
    
    var active: Bool
    
    var startedOn: String?
}
