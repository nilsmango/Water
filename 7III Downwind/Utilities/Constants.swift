//
//  Constants.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation

enum Constants {
    static let keychainKey = "DWUserData"
    static let keychainSessionsCount = "SessionsCount"
    static let baseURL = "https://7iii-dw-api-damp-lake-8537.fly.dev"
    
    /// height of the run map in meter
    static let heightOfMap = 300.0
    
    /// location up-, and downloading timer interval in seconds
    static let locationTimerInterval: Double = 120
    
    /// min accuracy to use in statistics
    static let minHorizontalAccuracy = 18.0
    
    /// timer interval for the information toggling in the online locations view (run)
    static let updateTimer: Double = 5.0
    
    /// max character number for username and status
    static let maxLengthUser = 15
    
    static let deepLinkBase = "project7iii.location://"
    
    static let defaultValue = 9999.9
        
    static let locationSampleData = [LocationData(timestamp: Date().addingTimeInterval(-172800), latitude: 46.89195421528713, longitude: 6.778561184189076, speed: 0.0),]
    
    // metadata keys for health kit
    static let customMetadataKeyWorkoutType = "7III Workout Type"
    static let customMetadataKeyTags = "Tags"
    static let customTotalDistanceKey = "Total Distance"
    static let customLocationKey = "Location"
    
    // video overlay and preview
    static let previewContainerWidth: Double = 400.0
    static let previewContainerHeightMultiple: Double = 0.2775
    static let previewContainerHeightMultipleLocation: Double = 0.3
}

enum Endpoints {
    static let members = "/members"
    static let runs = "/runs"
    static let byname = "/byname"
    static let checkUpdateMembers = "/members/checkAndUpdate"
    // TODO: remove this
    static let songs = "/songs"
}

