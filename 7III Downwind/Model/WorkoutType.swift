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
    case wingFoil = "WingFoil"
    case windFoil = "WindFoil"
    case kiteFoil = "KiteFoil"
    case kite = "Kite"
    case surf = "Surf"
    case windsurf = "Windsurf"
    case pumpFoil = "PumpFoil"
    case wakeThief = "WakeThief"
    case wakeFoil = "WakeFoil"
    case surfingSport = "SurfingSport"
    case paddleSport = "PaddleSport"
    case sup = "SUP"
    case kayak = "Kayak"
    case canoe = "Canoe"
    case supSurf = "SUPSurf"
    
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
            return "Surfing"
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
        }
    }
    var activityType: HKWorkoutActivityType {
            switch self {
            case .foilSurf, .supFoil, .downwindSUPFoil, .downwindSUP, .wingFoil, .windFoil, .kiteFoil, .kite, .surf, .windsurf, .pumpFoil, .wakeThief, .wakeFoil, .surfingSport, .supSurf:
                return .surfingSports
            case .paddleSport, .sup, .kayak, .canoe:
                return .paddleSports
            }
        }
}
