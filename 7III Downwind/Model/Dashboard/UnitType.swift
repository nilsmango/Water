//
//  UnitType.swift
//  WebTracker
//
//  Created by Simon Lang on 30.07.2025.
//

import Foundation

enum UnitType: String, CaseIterable, Codable {
    // Default
    case none = "None"
    case kilometersPerHour = "km/h"
    case knots = "kn"
    case beaufort = "Bft"
    case metersPerSecond = "m/s"
    case milesPerHour = "mph"
    
    // Temperature
    case celsius = "°C"
    case fahrenheit = "°F"
    
    var isTemperature: Bool {
        switch self {
        case .celsius, .fahrenheit:
            return true
        default:
            return false
        }
    }
}
