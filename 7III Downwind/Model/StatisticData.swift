//
//  StatisticData.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import Foundation

struct StatisticData: Codable {
    var date: Date
    var latitude: Double
    var longitude: Double
    
    // speed in km/h from CoreLocation
    var speed: Double?
}
