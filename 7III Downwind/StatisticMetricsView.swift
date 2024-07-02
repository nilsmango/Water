//
//  StatisticMetricsView.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.07.2024.
//

import SwiftUI

struct StatisticMetricsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Total Time")
                    .font(.caption)
                
                Text(durationFormatter.string(from: downwindManager.workout?.duration ?? 0.0) ?? "")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(width: width, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text("Total Distance")
                    .font(.caption)
                
                Text(makePrettyDistance(meters: runDistance, system: downwindManager.measurementSystem, statistics: true))
                    .monospacedDigit()
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(width: width, alignment: .leading)
        }
        
        HStack {
            VStack(alignment: .leading) {
                Text("∅-Speed")
                    .font(.caption)
                
                Text(averageSpeed)
                    .monospacedDigit()
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(width: width, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text("Top Speed")
                    .font(.caption)
                
                Text(makePrettySpeed(speed: topSpeed) system: downwindManager.measurementSystem))
                    .monospacedDigit()
                    .font(.body)
                    .foregroundColor(.primary)
                
            }
            .frame(width: width, alignment: .leading)
        }
    }
}

#Preview {
    VStack {
        StatisticMetricsView(startDate: Date.now, runDistance: <#T##Double#>, averageSpeed: <#T##Double#>, topSpeed: <#T##Double#>)
    }
}
