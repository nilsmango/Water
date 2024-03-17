//
//  StatisticsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

struct StatisticsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var body: some View {
        List {
            ForEach(downwindManager.runStatistics) { statistic in
                let averageSpeed = makePrettySpeed(speed: (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                RunOverView(runDate: downwindManager.createDateString(from: statistic.data.first?.date), runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeed)
            }
        }
            .navigationTitle("Run Statistics")
    }
}

#Preview {
    StatisticsView(downwindManager: DownwindManager())
}
