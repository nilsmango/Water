//
//  RunEdit.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import Foundation

struct RunEdit: Identifiable, Codable {
    var id: UUID
    
    var startLocation: LocationData?
    var finishLocation: LocationData?
    var deletedLocations: [LocationData]?
    /// time in minutes
    var newTotalTime: Double?
    /// total distance in meter
    var newTotalDistance: Double?
    /// top speed in km/h
    var newTopSpeed: Double?
    /// 10 sec top speed in km/h
    var topSpeed10s: Double?
    /// 1 sec top speed in km/h
    var topSpeed1s: Double?
    /// average speed in km/h
    var newAverageSpeed: Double?
    
    
//    var newKCalories: Double?
//    var newAverageHeartRate: Double?
    
    var newTags: [String]?
    
    var newWorkoutType: WorkoutType?
    var locationString: String?
}
