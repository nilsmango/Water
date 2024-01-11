//
//  DBRun.swift
//  7III Downwind
//
//  Created by Simon Lang on 31.12.23.
//

import Foundation

struct DBRun: Identifiable, Codable {
    var id: UUID?
    
    var name: String
    
    var startedOn: String?
    
}
