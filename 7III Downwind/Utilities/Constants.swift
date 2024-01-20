//
//  Constants.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation

enum Constants {
    static let keychainKey = "DWUserData"
    static let baseURL = "https://e065-194-191-224-88.ngrok-free.app"
    
    /// height of the run map in meter
    static let heightOfMap = 300.0
    
    /// location up-, and downloading timer interval in seconds
    static let locationTimerInterval: Double = 30
}

enum Endpoints {
    static let members = "/members"
    static let runs = "/runs"
    static let byname = "/byname"
    static let checkUpdateMembers = "/members/checkAndUpdate"
    // TODO: remove this
    static let songs = "/songs"
}
