//
//  WavesHelpers.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import Foundation

func partsBetweenWaves(locationData: [LocationData], waves: [[LocationData]]) -> [[LocationData]] {
    let wavePoints = Set(waves.flatMap { $0 })
    
    var result: [[LocationData]] = []
    var currentPart: [LocationData] = []
    
    for point in locationData {
        if wavePoints.contains(point) {
            if currentPart.count == 1 {
                currentPart = []
                currentPart.append(point)
            } else if !currentPart.isEmpty {
                    currentPart.append(point)
                    result.append(currentPart)
                    currentPart = []
            } else {
                currentPart.append(point)
            }
        } else {
            currentPart.append(point)
        }
    }
    
    if !currentPart.isEmpty {
        result.append(currentPart)
    }
    
    return result
}
