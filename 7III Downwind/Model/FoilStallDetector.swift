//
//  FoilStallDetector.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.10.2025.
//

import Foundation
import CoreLocation


struct StallEvent {
    let timestamp: Date
    let stallSpeed: Double // Speed before the drop
    let dropToSpeed: Double // Speed after the drop
    let speedDrop: Double // Magnitude of drop
    let index: Int // Index in original array
}

class FoilStallDetector {
    
    /// Detects the last stall speed before the end of the session
    /// - Parameters:
    ///   - locations: Array of location data
    ///   - speedDropThreshold: Minimum speed drop in m/s to consider a stall (default: 2.0 m/s)
    ///   - minSpeedBeforeDrop: Minimum speed before drop to consider valid (default: 3.0 m/s)
    /// - Returns: The stall speed, or nil if no stall detected
    static func detectLastStallSpeed(
        from locations: [LocationData],
        speedDropThreshold: Double = 1.7,
        minSpeedBeforeDrop: Double = 2.78
    ) -> Double? {
        
        let allStalls = detectAllStallSpeeds(
            from: locations,
            stallThreshold: speedDropThreshold,
            minFlyingSpeed: minSpeedBeforeDrop
        )
        
        return allStalls.last?.stallSpeed
    }
    
    /// Detects all stall events in the location data
    /// - Parameters:
    ///   - locations: Array of location data
    ///   - speedDropThreshold: Minimum speed drop in m/s to consider a stall (default: 2.0 m/s)
    ///   - minSpeedBeforeDrop: Minimum speed before drop to consider valid (default: 3.0 m/s)
    ///   - windowSize: Number of points to average for smoothing (default: 3)
    /// - Returns: Array of all detected stall events
    static func detectAllStallSpeeds(
        from locations: [LocationData],
        stallThreshold: Double = 1.7,   // "almost stopped"
        minFlyingSpeed: Double = 2.78,   // "definitely flying"
        minStallDuration: TimeInterval = 1   // seconds
    ) -> [StallEvent] {
        
        guard locations.count >= 2 else { return [] }
        
        // Extract valid speeds with timestamps
        var speeds: [(index: Int, speed: Double, time: Date)] = []
        for (i, loc) in locations.enumerated() {
            if let speed = loc.speed, speed >= 0 {
                speeds.append((i, speed, loc.timestamp))
            }
        }
        
        guard speeds.count >= 2 else { return [] }
        
        var stallEvents: [StallEvent] = []
        var i = 0
        
        while i < speeds.count - 1 {
            let currentSpeed = speeds[i].speed
            let nextSpeed = speeds[i + 1].speed
            
            // Possible stall starts here
            if currentSpeed >= minFlyingSpeed && nextSpeed <= stallThreshold {
                
                // Look ahead to see how long we stay below stallThreshold
                var j = i + 1
                while j < speeds.count && speeds[j].speed <= stallThreshold {
                    j += 1
                }
                
                // Check duration of low-speed segment
                let stallStartTime = speeds[i + 1].time
                let stallEndTime   = speeds[j - 1].time
                let stallDuration  = stallEndTime.timeIntervalSince(stallStartTime)
                
                if stallDuration >= minStallDuration {
                    let originalIndex = speeds[i + 1].index
                    let event = StallEvent(
                        timestamp: stallStartTime,
                        stallSpeed: currentSpeed,
                        dropToSpeed: nextSpeed,
                        speedDrop: currentSpeed - nextSpeed,
                        index: originalIndex
                    )
                    stallEvents.append(event)
                }
                
                // Skip past this stall segment
                i = j
            } else {
                i += 1
            }
        }
        
        return stallEvents
    }
    
    /// Calculates speed from consecutive location points if speed data is missing
    /// - Parameters:
    ///   - from: Starting location
    ///   - to: Ending location
    /// - Returns: Speed in m/s
    static func calculateSpeed(from: LocationData, to: LocationData) -> Double? {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        
        let distance = fromLoc.distance(from: toLoc) // meters
        let timeDiff = to.timestamp.timeIntervalSince(from.timestamp) // seconds
        
        guard timeDiff > 0 else { return nil }
        
        return distance / timeDiff
    }
    
    /// Prints a formatted report of all stall events
    static func printStallReport(_ events: [StallEvent]) {
        guard !events.isEmpty else {
            print("No stall events detected")
            return
        }
        
        print("\n=== Foil Stall Events Detected: \(events.count) ===\n")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        for (i, event) in events.enumerated() {
            print("Stall #\(i + 1)")
            print("  Time: \(formatter.string(from: event.timestamp))")
            print("  Stall Speed: \(String(format: "%.2f", event.stallSpeed)) m/s (\(String(format: "%.1f", event.stallSpeed * 3.6)) km/h)")
            print("  Dropped to: \(String(format: "%.2f", event.dropToSpeed)) m/s")
            print("  Speed Drop: \(String(format: "%.2f", event.speedDrop)) m/s")
            print("")
        }
        
        let avgStallSpeed = events.map { $0.stallSpeed }.reduce(0, +) / Double(events.count)
        print("Average Stall Speed: \(String(format: "%.2f", avgStallSpeed)) m/s (\(String(format: "%.1f", avgStallSpeed * 3.6)) km/h)")
    }
}

// MARK: - Example Usage

func exampleUsage() {
    // Sample data simulating a foiling session
    let baseDate = Date()
    var sampleData: [LocationData] = []
    
    // Building up speed
    for i in 0..<10 {
        sampleData.append(LocationData(
            timestamp: baseDate.addingTimeInterval(Double(i)),
            latitude: 46.0 + Double(i) * 0.0001,
            longitude: 7.0 + Double(i) * 0.0001,
            speed: Double(i) * 0.8
        ))
    }
    
    // First stall event at speed ~8 m/s
    sampleData.append(LocationData(
        timestamp: baseDate.addingTimeInterval(10),
        latitude: 46.001,
        longitude: 7.001,
        speed: 8.2
    ))
    
    sampleData.append(LocationData(
        timestamp: baseDate.addingTimeInterval(11),
        latitude: 46.0011,
        longitude: 7.0011,
        speed: 3.5 // Sharp drop!
    ))
    
    // Recovery
    for i in 12..<20 {
        sampleData.append(LocationData(
            timestamp: baseDate.addingTimeInterval(Double(i)),
            latitude: 46.001 + Double(i - 12) * 0.0001,
            longitude: 7.001 + Double(i - 12) * 0.0001,
            speed: 4.0 + Double(i - 12) * 0.5
        ))
    }
    
    // Second stall at speed ~9 m/s
    sampleData.append(LocationData(
        timestamp: baseDate.addingTimeInterval(20),
        latitude: 46.002,
        longitude: 7.002,
        speed: 9.5
    ))
    
    sampleData.append(LocationData(
        timestamp: baseDate.addingTimeInterval(21),
        latitude: 46.0021,
        longitude: 7.0021,
        speed: 4.0 // Sharp drop!
    ))
    
    // Get last stall speed
    if let lastStall = FoilStallDetector.detectLastStallSpeed(from: sampleData) {
        print("Last Stall Speed: \(String(format: "%.2f", lastStall)) m/s (\(String(format: "%.1f", lastStall * 3.6)) km/h)\n")
    }
    
    // Get all stall events
    let allStalls = FoilStallDetector.detectAllStallSpeeds(from: sampleData)
    FoilStallDetector.printStallReport(allStalls)
}

// Run example
//exampleUsage()
