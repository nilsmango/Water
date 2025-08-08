//
//  Dashboard.swift
//  WebTracker
//
//  Created by Simon Lang on 29.07.2025.
//

import Foundation

struct Dashboard: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var elements: [TrackedElement]
    var info: String?
    
    init(id: UUID = UUID(), name: String, elements: [TrackedElement], info: String? = nil) {
        self.id = id
        self.name = name
        self.elements = elements
        self.info = info
    }
}
