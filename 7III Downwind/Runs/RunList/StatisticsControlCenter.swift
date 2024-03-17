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
            
            let currentRunStatistic = downwindManager.runStatistics[downwindManager.currentRunStatisticIndex]
            Text("Distance: \(makePrettyDistance(meters: currentRunStatistic.runDistance, system: downwindManager.measurementSystem))")
            Text("Time: \(Text(downwindManager.activeRun.startedOn ?? Date.now, style: .timer))")
                .monospacedDigit()
            let averageSpeed = makePrettySpeed(speed: currentRunStatistic.runDistance / (currentRunStatistic.runTime / 60), system: downwindManager.measurementSystem)
            Text("Average Speed: \(averageSpeed)")
        }
        

    }
}

#Preview {
    StatisticsControlCenter(downwindManager: DownwindManager())
}
