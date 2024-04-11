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
                let runDates = downwindManager.makeTimeIntervalDate(startDate: statistic.locationData.first?.timestamp ?? Date.now, endDate: statistic.locationData.last?.timestamp ?? Date.now)
                
                NavigationLink {
                    StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic, averageSpeed: averageSpeed, runDates: runDates)
                } label: {
                    RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeed)
                }
            }
            .onDelete { indexSet in
                downwindManager.delete(at: indexSet)
            }
            
        }
            .navigationTitle("Run Statistics")
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Filter by Tags") {
                        TagsListView(downwindManager: downwindManager)
                    }
                }
            }
    }
}

#Preview {
    NavigationStack {
        StatisticsView(downwindManager: DownwindManager())
    }
}
