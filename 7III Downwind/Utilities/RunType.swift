//
//  RunType.swift
//  7III Downwind
//
//  Created by Simon Lang on 23.01.2024.
//

import Foundation

enum RunType {
    case start, join, watch
    
    var textFieldText: String {
        switch self {
        case .start:
            return "Enter new run name here"
        case .join:
            return "Enter run to join here"
        case .watch:
            return "Enter run to watch here"
        }
    }
    
    var buttonLabel: String {
        switch self {
        case .start:
            return "Start Run"
        case .join:
            return "Join Run"
        case .watch:
            return "Watch Run"
        }
    }
    
    var symbol: String {
        switch self {
        case .start:
            "wind.snow"
        case .join:
            "wind"
        case .watch:
            "wind"
        }
    }
}
