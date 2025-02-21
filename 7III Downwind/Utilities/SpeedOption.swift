//
//  SpeedOption.swift
//  7III Tracker
//
//  Created by Simon Lang on 24.07.2024.
//

import Foundation

enum SpeedOption: String, CaseIterable {
    case speed = "∅-Speed"
    case pace = "∅-Pace"
}

enum TopSpeedOption: String, CaseIterable {
    case gps = "GPS Top Speed"
    case top1 = "1s Top Speed"
    case top10 = "10s Top Speed"
    
}
