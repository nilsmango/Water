//
//  Song.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation

struct Song: Identifiable, Codable {
    let id: UUID?
    var title: String
}
