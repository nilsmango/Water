//
//  WorkoutType.swift
//  7III Tracker
//
//  Created by Simon Lang on 11.06.2024.
//

import Foundation
import HealthKit

enum WorkoutType: String, Codable, CaseIterable {
    case foilSurf = "FoilSurf"
    case supFoil = "SUPFoil"
    case downwindSUPFoil = "DownwindSUPFoil"
    case downwindSUP = "DownwindSUP"
    case downwindProneFoil = "DWProneFoil"
    case wingFoil = "WingFoil"
    case parawing = "Parawing"
    case paraUpDown = "ParaUpDown"
    case dWParawing = "DWParawing"
    case windFoil = "WindFoil"
    case kiteFoil = "KiteFoil"
    case kite = "Kite"
    case windsurf = "Windsurf"
    case pumpFoil = "PumpFoil"
    case wakeThief = "WakeThief"
    case wakeFoil = "WakeFoil"
    case wakeSurf = "WakeSurf"
    case sailing = "Sailing"
    case surfingSport = "SurfingSport"
    case paddleSport = "PaddleSport"
    case sup = "SUP"
    case supSurf = "SUPSurf"
    case kayak = "Kayak"
    case canoe = "Canoe"
    case not7IIISurfingSport = "Not7IIISurfingSport"
    case not7IIIPaddleSport = "Not7IIIPaddleSport"
    case surf = "Surf"
    case windSkate = "WindSkate"
    case wingSkate = "WingSkate"
    case surfSkate = "SurfSkate"
    case pumpSkate = "PumpSkate"
    case pwSkate = "PWSkate"
    case eFoil = "eFoil"
    case eAssist = "eAssist"
    
    
    var prettyString: String {
        switch self {
        case .foilSurf:
            return "Foil Surf"
        case .supFoil:
            return "SUP Foil"
        case .downwindSUPFoil:
            return "DW SUP Foil"
        case .downwindSUP:
            return "DW SUP"
        case .wingFoil:
            return "Wing Foil"
        case .windFoil:
            return "Wind Foil"
        case .kiteFoil:
            return "Kite Foil"
        case .kite:
            return "Kite"
        case .surf:
            return "Surf"
        case .windsurf:
            return "Windsurf"
        case .pumpFoil:
            return "Pump Foil"
        case .wakeThief:
            return "Wake Thief"
        case .wakeFoil:
            return "Wake Foil"
        case .surfingSport:
            return "Surf"
        case .paddleSport:
            return "Paddling"
        case .sup:
            return "SUP"
        case .kayak:
            return "Kayak"
        case .canoe:
            return "Canoe"
        case .supSurf:
            return "SUP Surf"
        case .not7IIISurfingSport:
            return "Surf"
        case .not7IIIPaddleSport:
            return "Paddle"
        case .windSkate:
            return "Wind Skate"
        case .wingSkate:
            return "Wing Skate"
        case .surfSkate:
            return "Surf Skate"
        case .pumpSkate:
            return "Pump Skate"
        case .wakeSurf:
            return "Wake Surf"
        case .downwindProneFoil:
            return "DW Prone Foil"
        case .sailing:
            return "Sailing"
        case .parawing:
            return "Parawing"
        case .dWParawing:
            return "DW Parawing"
        case .pwSkate:
            return "PW Skate"
        case .eFoil:
            return "E-Foil"
        case .eAssist:
            return "E-Assist"
        case .paraUpDown:
            return "UDW Parawing"
        }
    }
    var activityType: HKWorkoutActivityType {
            switch self {
            case .foilSurf, .supFoil, .downwindSUPFoil, .downwindSUP, .wingFoil, .windFoil, .kiteFoil, .kite, .surf, .windsurf, .pumpFoil, .wakeThief, .wakeFoil, .surfingSport, .supSurf, .not7IIISurfingSport, .wakeSurf, .downwindProneFoil, .parawing, .dWParawing, .eFoil, .eAssist, .paraUpDown:
                return .surfingSports
            case .paddleSport, .sup, .kayak, .canoe, .not7IIIPaddleSport:
                return .paddleSports
            case .windSkate, .wingSkate, .surfSkate, .pumpSkate, .pwSkate:
                return .surfingSports
            case .sailing:
                return .sailing
            }
    }
    
    var isDWSport: Bool {
        switch self {
        case .downwindSUP, .downwindSUPFoil, .downwindProneFoil, .dWParawing:
            return true
        default:
            return false
        }
    }
    
    var isUpDownwindSport: Bool {
        switch self {
        case .paraUpDown:
            return true
        default:
            return false
        }
    }
    
    var countTurns: Bool {
        switch self {
        case .downwindSUP, .downwindSUPFoil, .downwindProneFoil, .dWParawing, .kiteFoil, .wingFoil, .parawing, .windFoil, .eFoil, .eAssist, .surf, .supSurf, .foilSurf, .supFoil, .wakeFoil, .wakeSurf, .paraUpDown:
            return true
        default:
            return false
        }
    }
    
    var calculateFoilingStats: Bool {
        switch self {
        case .downwindSUPFoil, .downwindProneFoil, .dWParawing, .kiteFoil, .wingFoil, .parawing, .windFoil, .pumpFoil, .eFoil, .eAssist, .surf, .supSurf, .foilSurf, .supFoil, .wakeFoil, .wakeSurf, .wakeThief, .paraUpDown:
            return true
        default:
            return false
        }
    }
    
    var returnWaves: Bool {
        switch self {
        case .pumpFoil, .foilSurf, .wakeThief, .supFoil, .wakeFoil, .wakeSurf:
            return true
        default:
            return false
        }
    }
    
    var angleSport: Bool {
        switch self {
        case .parawing, .dWParawing, .windsurf, .windFoil, .wingFoil, .wingSkate, .windSkate, .kite, .kiteFoil, .sailing, .pwSkate, .paraUpDown:
            return true
        default:
            return false
        }
    }
}

enum StatisticsMapStyle: String, Codable, CaseIterable, Identifiable {
    case neonYellow
    case gradient
    case downwindGradient
    
    var id: String {
        rawValue
    }
    
    var title: String {
        switch self {
        case .neonYellow:
            return "Neon Yellow"
        case .gradient:
            return "Gradient"
        case .downwindGradient:
            return "Downwind Gradient"
        }
    }
}


extension WorkoutType {
    var appStorageKey: String {
        "thresholdSpeedKmhSlowSpeed_\(self.rawValue)"
    }
    
    var statisticsMapStyleStorageKey: String {
        "statisticsMapStyle_\(self.rawValue)"
    }

    var thresholdSpeedKmhSlowSpeed: Double {
        get {
            UserDefaults.standard.double(forKey: appStorageKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: appStorageKey)
        }
    }

    var defaultThresholdSpeed: Double {
        switch self {
        case .surf, .supSurf, .foilSurf, .supFoil, .wakeFoil, .wakeSurf, .wakeThief: return 11.2
        case .downwindSUPFoil, .downwindProneFoil, .dWParawing, .kiteFoil, .wingFoil, .parawing, .windFoil, .pumpFoil, .eFoil, .eAssist, .paraUpDown: return 8.0
        default: return 10.0
        }
    }

    var thresholdSpeedKmhSlowSpeedWithDefault: Double {
        let value = thresholdSpeedKmhSlowSpeed
        return value > 0 ? value : defaultThresholdSpeed
    }
    
    var defaultStatisticsMapStyle: StatisticsMapStyle {
        isDWSport ? .downwindGradient : .gradient
    }
    
    var statisticsMapStyle: StatisticsMapStyle {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: statisticsMapStyleStorageKey) else {
                return defaultStatisticsMapStyle
            }
            
            return StatisticsMapStyle(rawValue: rawValue) ?? defaultStatisticsMapStyle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: statisticsMapStyleStorageKey)
        }
    }
    
    static func setThreshold(_ value: Double, for type: WorkoutType) {
        UserDefaults.standard.set(value, forKey: type.appStorageKey)
    }
    
    static func setStatisticsMapStyle(_ style: StatisticsMapStyle, for type: WorkoutType) {
        UserDefaults.standard.set(style.rawValue, forKey: type.statisticsMapStyleStorageKey)
    }
}
