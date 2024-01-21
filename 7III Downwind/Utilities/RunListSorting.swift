//
//  RunListSorting.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.01.24.
//

import Foundation

enum RunListSorting: String, CaseIterable, Identifiable, Codable {
    case name = "Name"
    case distanceDescending = "Descending"
    case distanceAscending = "Ascending"
    
    var id: Self { self }
}
