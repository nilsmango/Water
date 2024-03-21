//
//  RunStatistic.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import Foundation

struct RunStatistic: Identifiable, Codable {
    let id: UUID
    var runName: String
    var crewStatistics: [CrewStatistic]
    
    /// time in minutes
    var runTime: Double
    /// distance in meters
    var runDistance: Double
    /// top speed in km/h
    var topSpeed: Double
    
    var data: [StatisticData]
    
}
