//
//  AngleSection.swift
//  7III Tracker
//
//  Created by Simon Lang on 09.11.2025.
//

import SwiftUI

struct AngleSection: View {
    let angles: [MapAngle]
    
    let width = UIScreen.main.bounds.width / 3

    var body: some View {
        HStack {
            if angles.count > 1 {
                StatisticsInfoViews(
                    header: "Average Angle",
                    bodyText: averageAngle
                )
                .frame(width: width, alignment: .leading)
                
                StatisticsInfoViews(
                    header: "Best Angle",
                    bodyText: bestAngle
                )
            } else {
                StatisticsInfoViews(
                    header: "Angle",
                    bodyText: angles.first?.angle ?? "N/A"
                )
                .frame(width: width, alignment: .leading)
            }
            
            
            
        }
    }
    
    // Computed property for average angle
    private var averageAngle: String {
        let numericAngles = angles.compactMap { angle -> Double? in
            // Remove "°" symbol and convert to Double
            let cleanedString = angle.angle.replacingOccurrences(of: "°", with: "").trimmingCharacters(in: .whitespaces)
            return Double(cleanedString)
        }
        
        guard !numericAngles.isEmpty else {
            return "N/A"
        }
        
        let average = numericAngles.reduce(0, +) / Double(numericAngles.count)
        return String(format: "%.1f°", average)
    }
    
    // Computed property for best (steepest) angle
    private var bestAngle: String {
        let numericAngles = angles.compactMap { angle -> Double? in
            let cleanedString = angle.angle.replacingOccurrences(of: "°", with: "").trimmingCharacters(in: .whitespaces)
            return Double(cleanedString)
        }
        
        guard let maxAngle = numericAngles.max() else {
            return "N/A"
        }
        
        return String(format: "%.1f°", maxAngle)
    }
}

#Preview {
    AngleSection(angles: [])
}
