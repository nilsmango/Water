//
//  Version.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.02.2025.
//

import Foundation

struct Version {
    let versionNumber: String
    let introduction: String
    let changes: [String]
    
    /// should be in form of "September 2024"
    let releaseDate: String
}
