//
//  StatisticData.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import Foundation

struct LocationData: Codable, Equatable, Hashable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    
    // speed in m/s from CoreLocation
    var speed: Double?
    var verticalAccuracy: Double?
    
    static func == (lhs: LocationData, rhs: LocationData) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.speed == rhs.speed
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(speed)
    }
}
