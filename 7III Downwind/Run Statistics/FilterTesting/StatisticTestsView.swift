//
//  StatisticTestsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

/// makes locations for raw gps data with different kalman filter parameters
struct StatisticTestsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var showSheet = false
    
    var body: some View {
        List {
            ForEach(downwindManager.runStatistics) { statistic in
                let averageSpeed = makePrettySpeed(speed: (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                
                Button {
                    downwindManager.testStatistics = downwindManager.makingKalmanVersions(statistic: statistic)
                    showSheet = true
                    
                } label: {
                    RunOverView(runDate: downwindManager.createDateString(from: statistic.locationData.first?.timestamp), runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeed, kCal: "\(Int(statistic.kCalories?.rounded() ?? 0)) kcal")
                }
            }
            .onDelete { indexSet in
                downwindManager.delete(at: indexSet)
            }
        }
            .navigationTitle("Run Statistics")
            .sheet(isPresented: $showSheet, content: {
                NavigationStack {
                    StatisticsModelings(downwindManager: downwindManager, strings: downwindManager.makingSigmaAndRs())
                }
                
            })
    }
}

#Preview {
    StatisticTestsView(downwindManager: DownwindManager())
}
