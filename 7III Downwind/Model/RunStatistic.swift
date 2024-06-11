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
    /// average speed in km/h
    var averageSpeed: Double?
    var kCalories: Double?
    var heartRates: [Double]?
    var averageHeartRate: Double?
    
    var locationData: [LocationData]
    
    var tags: [String]?
    var workoutType: WorkoutType?
    var startDate: Date?
    var endDate: Date?
    
    init(from workout: HKWorkout, locationData: [LocationData]) {
            self.id = workout.uuid
            self.runName = workout.workoutActivityType == .paddleSports ? "Paddle Sport" : "Surfing Sport"
            self.crewStatistics = []
            self.runTime = workout.duration / 60 // Convert seconds to minutes
            self.runDistance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            self.topSpeed = 0 // Need to calculate this
            self.kCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            self.heartRates = [] // Need to fetch samples
            self.averageHeartRate = 0 // Need to calculate this
            self.locationData = locationData
            self.tags = []
        }
    
    // Parameterless initializer for empty()
        init() {
            self.id = UUID()
            self.runName = ""
            self.crewStatistics = []
            self.runTime = 0
            self.runDistance = 0
            self.topSpeed = 0
            self.kCalories = 0
            self.heartRates = []
            self.averageHeartRate = 0
            self.locationData = []
            self.tags = []
        }
        
        // Custom initializer for direct initialization 1
    init(id: UUID, runName: String, crewStatistics: [CrewStatistic], runTime: Double, runDistance: Double, topSpeed: Double, averageSpeed: Double, kCalories: Double, locationData: [LocationData], tags: [String], workoutType: WorkoutType, startDate: Date, endDate: Date) {
        self.id = id
        self.runName = runName
        self.crewStatistics = crewStatistics
        self.runTime = runTime
        self.runDistance = runDistance
        self.topSpeed = topSpeed
        self.kCalories = kCalories
//        self.heartRates = [] // Assuming heart rates are not provided in this initializer
//        self.averageHeartRate = 0 // Assuming average heart rate is not provided in this initializer
        self.locationData = locationData
        self.tags = tags
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
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

    mutating func merge(with other: RunStatistic) {
        // TODO: Implement merging logic merging everything from health with the tags and crewstatistic already in the runStatistics array
    }
}
