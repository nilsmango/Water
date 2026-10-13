//
//  ImportRun.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.04.2025.
//

import Foundation

struct ImportRun: Identifiable, Codable {
    let id: UUID
    /// time in minutes
    let runTime: Double
    /// Measured GPS top speed in km/h
    var topSpeed: Double
    
    var averageSpeed: Double
    var totalDistance: Double
    var startLocation: LocationData?

    var locations: [LocationData]
    let heartRates: [HeartRate]
    let averageHeartRate: Double
    
    var workoutType: WorkoutType?
    var tags: [String] = []
    var locationString: String?
}

struct HeartRate: Codable {
    var date: Date
    var heartRate: Double
}
