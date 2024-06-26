//
//  StatisticData.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import Foundation

struct LocationData: Codable, Equatable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    
    // speed in m/s from CoreLocation
    var speed: Double?
}
