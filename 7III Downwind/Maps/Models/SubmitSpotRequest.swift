//
//  SubmitSpotRequest.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import Foundation

struct SubmitSpotRequest: Codable {
    let name: String
    let kind: String
    let country: String
    let usState: String?
    let locations: [[String: Double]]
    let distance: Double?
    let infos: [SpotInfo]
    let videos: [Video]
}

struct SubmitSpotResponse: Codable {
    let success: Bool
    let spotId: String?
    let message: String?
}
