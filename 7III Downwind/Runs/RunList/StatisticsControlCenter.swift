//
//  StatisticsControlCenter.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

struct StatisticsControlCenter: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var body: some View {
        if downwindManager.activeStatistics == false {
            Button {
                downwindManager.startStatistic()
                downwindManager.activeRun.startedOn = Date.now
            } label: {
                Label("Start Statistics", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .padding()
            
        } else {
            Button(role: .destructive) {
                downwindManager.stopStatistic()
            } label: {
                Label("Stop Statistics", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .padding()
            
            Text("Time: \(Text(downwindManager.activeRun.startedOn ?? Date.now, style: .timer))")
                .monospacedDigit()
            
            let currentRunStatistic = downwindManager.runStatistics[downwindManager.currentRunStatisticIndex]
            
            Text("Distance: \(makePrettyDistance(meters: currentRunStatistic.runDistance, system: downwindManager.measurementSystem))")
            
            let averageSpeed = makePrettySpeed(speed: (currentRunStatistic.runDistance / 1000) / (currentRunStatistic.runTime / 60), system: downwindManager.measurementSystem)
            Text("Average Speed: \(averageSpeed)")
            
            Text("Top Speed: \(makePrettySpeed(speed: currentRunStatistic.topSpeed, system: downwindManager.measurementSystem))")
        }
        

    }
}

#Preview {
    StatisticsControlCenter(downwindManager: DownwindManager())
}
