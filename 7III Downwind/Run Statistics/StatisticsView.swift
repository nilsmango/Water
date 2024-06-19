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
            ForEach(0..<downwindManager.groupedRunStatistics.count, id: \.self) { yearIndex in
                    ForEach(0..<downwindManager.groupedRunStatistics[yearIndex].count, id: \.self) { monthIndex in
                        Section {
                            ForEach(downwindManager.groupedRunStatistics[yearIndex][monthIndex]) { statistic in
                                
                                let averageSpeedString = makePrettySpeed(speed: statistic.averageSpeed ?? (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                                let runDates = downwindManager.makeTimeIntervalDate(startDate: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.now, endDate: statistic.endDate ?? statistic.locationData.last?.timestamp ?? Date.now)
                                
                                NavigationLink {
                                    StatisticsRunView(downwindManager: downwindManager, statisticsData: binding(for: statistic))
                                } label: {
                                    RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeedString, kCal: "\(Int(statistic.kCalories?.rounded() ?? 0)) kcal", activityType: statistic.workoutType?.prettyString ?? "DW SUP Foil")
                                }
                            }
                            
                        } header: {
                            VStack(alignment: .leading) {
                                if monthIndex == 0 {
                                    Text(yearSectionHeader(yearIndex: yearIndex))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .padding(.bottom, 0)
                                    
                                    YearlyStatisticView(downwindManager: downwindManager, yearIndex: yearIndex)
                                }
                                Text(monthSectionHeader(yearIndex: yearIndex, monthIndex: monthIndex))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        }
                    }
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
    
    private func binding(for statistic: RunStatistic) -> Binding<RunStatistic> {
        guard let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statistic.id }) else {
            fatalError("Can't find the statistic in array")
        }
        return $downwindManager.runStatistics[index]
    }
    
    private func yearSectionHeader(yearIndex: Int) -> String {
        let year = Calendar.current.component(.year, from: downwindManager.groupedRunStatistics[yearIndex].first?.first?.startDate ?? Date.distantPast)
        return String(year)
    }

    private func monthSectionHeader(yearIndex: Int, monthIndex: Int) -> String {
        let month = Calendar.current.component(.month, from: downwindManager.groupedRunStatistics[yearIndex][monthIndex].first?.startDate ?? Date.distantPast)
        let monthName = Calendar.current.monthSymbols[month - 1]
        let year = Calendar.current.component(.year, from: downwindManager.groupedRunStatistics[yearIndex].first?.first?.startDate ?? Date.distantPast)
        let yearString = String(year % 100)
        return monthName + " " + yearString
    }
}

#Preview {
    NavigationStack {
        StatisticsView(downwindManager: DownwindManager())
    }
}
