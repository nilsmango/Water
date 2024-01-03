//
//  RunListSorting.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.01.24.
//

import Foundation

enum RunListSorting: String, CaseIterable, Identifiable, Codable {
    case custom = "Custom"
    case name = "Name"
    case distanceAscending = "Ascending"
    case distanceDescending = "Descending"
    
    var id: Self { self }
}
