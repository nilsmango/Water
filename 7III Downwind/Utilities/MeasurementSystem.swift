//
//  MeasurementSystem.swift
//  7III Downwind
//
//  Created by Simon Lang on 11.01.24.
//

import Foundation

enum MeasurementSystem:  String, CaseIterable, Identifiable, Codable  {
    case metric = "Metric"
    case imperial = "Imperial"
    
    var id: Self { self }
}
