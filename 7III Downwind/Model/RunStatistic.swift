//
//  RunStatistic.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import Foundation
import HealthKit

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
    /// 10 sec top speed in km/h
    var topSpeed10s: Double?
    /// 1 sec top speed in km/h
    var topSpeed1s: Double?
    /// average speed in km/h
    var averageSpeed: Double?
    var kCalories: Double?
    var averageHeartRate: Double?
    /// pop ups dedected
    var popUps: Int?
    /// percentage on foil of time
    var percentageOnFoil: Double?
    var turnsCount: Int?
    
    var locationData: [LocationData]
    
    var tags: [String]?
    var workoutType: WorkoutType?
    var startDate: Date?
    var endDate: Date?
    /// start location for workouts where you don't collect gps data
    var startLocation: LocationData?
    var locationString: String?
    
    
    // Parameterless initializer for empty()
        init() {
            self.id = UUID()
            self.runName = ""
            self.crewStatistics = []
            self.runTime = 0
            self.runDistance = 0
            self.topSpeed = 0
            self.kCalories = 0
            self.averageHeartRate = 0
            self.locationData = []
            self.tags = []
        }
        
        // Custom initializer for direct initialization 1
    init(id: UUID, runName: String, crewStatistics: [CrewStatistic], runTime: Double, runDistance: Double, topSpeed: Double, averageSpeed: Double, kCalories: Double, locationData: [LocationData], tags: [String], workoutType: WorkoutType, startDate: Date, endDate: Date, topSpeed1s: Double, topSpeed10s: Double, popUps: Int, percentageOnFoil: Double, turnsCount: Int) {
        self.id = id
        self.runName = runName
        self.crewStatistics = crewStatistics
        self.runTime = runTime
        self.runDistance = runDistance
        self.topSpeed = topSpeed
        self.topSpeed1s = topSpeed1s
        self.topSpeed10s = topSpeed10s
        self.kCalories = kCalories
//        self.heartRates = [] // Assuming heart rates are not provided in this initializer
//        self.averageHeartRate = 0 // Assuming average heart rate is not provided in this initializer
        self.locationData = locationData
        self.tags = tags
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.popUps = popUps
        self.percentageOnFoil = percentageOnFoil
        self.turnsCount = turnsCount
    }
    // Custom initializer for direct initialization 2
    init(id: UUID, runName: String, crewStatistics: [CrewStatistic], runTime: Double, runDistance: Double, topSpeed: Double, locationData: [LocationData], tags: [String]?) {
        self.id = id
        self.runName = runName
        self.crewStatistics = crewStatistics
        self.runTime = runTime
        self.runDistance = runDistance
        self.topSpeed = topSpeed
        self.locationData = locationData
        self.tags = tags

    }
    
    init(id: UUID, locationData: [LocationData], startLocation: LocationData?) {
        self.id = id
        self.runName = ""
        self.crewStatistics = []
        self.runTime = 0
        self.runDistance = 0
        self.topSpeed = 0
        self.kCalories = 0
        self.averageHeartRate = 0
        self.locationData = locationData
        self.tags = []
        self.startLocation = startLocation
    }
    
    
    // Custom initializer for direct initialization without tags
    init(id: UUID, runName: String, crewStatistics: [CrewStatistic], runTime: Double, runDistance: Double, topSpeed: Double, locationData: [LocationData]) {
        self.id = id
        self.runName = runName
        self.crewStatistics = crewStatistics
        self.runTime = runTime
        self.runDistance = runDistance
        self.topSpeed = topSpeed
//        self.kCalories = 0 // Assuming calories are not provided in this initializer
//        self.heartRates = [] // Assuming heart rates are not provided in this initializer
//        self.averageHeartRate = 0 // Assuming average heart rate is not provided in this initializer
        self.locationData = locationData
        self.tags = []
    }
}


extension RunStatistic {
    static func empty() -> RunStatistic {
        return RunStatistic()
    }
}
