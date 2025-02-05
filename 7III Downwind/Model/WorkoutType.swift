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
        }
    }
    var activityType: HKWorkoutActivityType {
            switch self {
            case .foilSurf, .supFoil, .downwindSUPFoil, .downwindSUP, .wingFoil, .windFoil, .kiteFoil, .kite, .surf, .windsurf, .pumpFoil, .wakeThief, .wakeFoil, .surfingSport, .supSurf, .not7IIISurfingSport, .wakeSurf, .downwindProneFoil, .parawing, .dWParawing:
                return .surfingSports
            case .paddleSport, .sup, .kayak, .canoe, .not7IIIPaddleSport:
                return .paddleSports
            case .windSkate, .wingSkate, .surfSkate, .pumpSkate:
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
}
