//
//  UnitConverter.swift
//  WebTracker
//
//  Created by Simon Lang on 30.07.2025.
//

import Foundation

struct UnitConverter {
    static func convert(_ value: Double, from: UnitType, to: UnitType) -> Double {
        switch (from, to) {
        // Wind conversions
        case (.kilometersPerHour, .knots): return value * 0.539957
        case (.knots, .kilometersPerHour): return value / 0.539957
        case (.kilometersPerHour, .milesPerHour): return value * 0.621371
        case (.milesPerHour, .kilometersPerHour): return value / 0.621371
        case (.kilometersPerHour, .metersPerSecond): return value / 3.6
        case (.metersPerSecond, .kilometersPerHour): return value * 3.6
        case (.knots, .milesPerHour): return value * 1.15078
        case (.milesPerHour, .knots): return value / 1.15078
        case (.metersPerSecond, .knots): return value * 1.94384
        case (.knots, .metersPerSecond): return value / 1.94384
        
        // Bft to others (approximate average conversions)
        case (.beaufort, .kilometersPerHour): return bftToKmh(value)
        case (.beaufort, .knots): return bftToKmh(value) * 0.539957
        case (.beaufort, .metersPerSecond): return bftToKmh(value) / 3.6
        case (.beaufort, .milesPerHour): return bftToKmh(value) * 0.621371

        // Others to Bft (rough approximation)
        case (.kilometersPerHour, .beaufort): return kmhToBft(value)
        case (.knots, .beaufort): return kmhToBft(value / 0.539957)
        case (.metersPerSecond, .beaufort): return kmhToBft(value * 3.6)
        case (.milesPerHour, .beaufort): return kmhToBft(value / 0.621371)

        // Temperature
        case (.celsius, .fahrenheit): return value * 9 / 5 + 32
        case (.fahrenheit, .celsius): return (value - 32) * 5 / 9

        default: return value
        }
    }
    
    private static func bftToKmh(_ bft: Double) -> Double {
        // Based on average midpoint values
        let table: [Double] = [0, 2, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118]
        let i = Int(bft.rounded())
        return (0...12).contains(i) ? table[i] : table.last!
    }

    private static func kmhToBft(_ kmh: Double) -> Double {
        switch kmh {
        case ..<1: return 0
        case ..<6: return 1
        case ..<12: return 2
        case ..<20: return 3
        case ..<29: return 4
        case ..<39: return 5
        case ..<50: return 6
        case ..<62: return 7
        case ..<75: return 8
        case ..<89: return 9
        case ..<103: return 10
        case ..<118: return 11
        default: return 12
        }
    }
}
