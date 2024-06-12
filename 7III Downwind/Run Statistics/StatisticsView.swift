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
            ForEach(groupedRunStatistics.keys.sorted(by: >), id: \.self) { year in
                Section(header: Text(String(year))) {
                    ForEach(groupedRunStatistics[year]!) { statistic in
                        
                        let averageSpeedString = makePrettySpeed(speed: statistic.averageSpeed ?? (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                        let runDates = downwindManager.makeTimeIntervalDate(startDate: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.now, endDate: statistic.endDate ?? statistic.locationData.last?.timestamp ?? Date.now)
                        
                        NavigationLink {
                            StatisticsRunView(downwindManager: downwindManager, statisticsData: binding(for: statistic))
                        } label: {
                            RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeedString, kCal: "\(Int(statistic.kCalories?.rounded() ?? 0)) kcal")
                        }
                    }
                    .onDelete { indexSet in
                        downwindManager.delete(at: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Run Statistics")
        .navigationBarItems(trailing: EditButton())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Filter by Tags") {
                    TagsListView(downwindManager: downwindManager)
                }
            }
        }
    }
    
    private func binding(for statistic: RunStatistic) -> Binding<RunStatistic> {
        guard let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statistic.id }) else {
            fatalError("Can't find the statistic in array")
        }
        return $downwindManager.runStatistics[index]
    }
    
    // Group statistics by year
        private var groupedRunStatistics: [Int: [RunStatistic]] {
            Dictionary(grouping: downwindManager.runStatistics) { statistic in
                Calendar.current.component(.year, from: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.distantPast)
            }
        }
}

#Preview {
    NavigationStack {
        StatisticsView(downwindManager: DownwindManager())
    }
}
