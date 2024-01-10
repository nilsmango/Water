//
//  Constants.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation

enum Constants {
    static let keychainKey = "DWUserData"
    static let baseURL = "https://2086-194-191-224-88.ngrok-free.app"
    
    /// height of the run map in meter
    static let heightOfMap = 300.0
}

enum Endpoints {
    static let members = "/members"
    static let runs = "/runs"
    static let checkUpdateMembers = "/members/checkAndUpdate"
    // TODO: remove this
    static let songs = "/songs"
}
