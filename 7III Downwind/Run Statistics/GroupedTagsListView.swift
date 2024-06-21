//
//  GroupedTagsListView.swift
//  7III Tracker
//
//  Created by Simon Lang on 21.06.2024.
//

import SwiftUI

struct GroupedTagsListView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var chosenTags = [String]()
    
    var filteredGroupedStatistics: [[[RunStatistic]]] { downwindManager.filterGroupedStatistics(tags: chosenTags) }
    
    var body: some View {
        // add a row of FlexibleView items that are buttons that will get added to the tags
        VStack {
            
            FlexibleView(
                data: downwindManager.tags,
                spacing: 5,
                alignment: .leading
            ) { string in
                
                SelectionButtonLabel(string: string, chosenStrings: $chosenTags, allStrings: downwindManager.tags)
                    .onTapGesture {
                        if chosenTags.contains(string) {
                            chosenTags.removeAll(where: { $0 == string})
                        } else {
                            chosenTags.append(string)
                        }
                    }
                
            }
            .padding()
            
            List {
                ForEach(0..<filteredGroupedStatistics.count, id: \.self) { yearIndex in
                    ForEach(0..<filteredGroupedStatistics[yearIndex].count, id: \.self) { monthIndex in
                        Section {
                            ForEach(filteredGroupedStatistics[yearIndex][monthIndex]) { statistic in
                                let averageSpeedString = makePrettySpeed(speed: statistic.averageSpeed ?? (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                                let runDates = downwindManager.makeTimeIntervalDate(startDate: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.now, endDate: statistic.endDate ?? statistic.locationData.last?.timestamp ?? Date.now)
                                
                                NavigationLink {
                                    StatisticsRunView(downwindManager: downwindManager, statisticsData: binding(for: statistic))
                                } label: {
                                    RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeedString, kCal: "\(Int(statistic.kCalories?.rounded() ?? 0)) kcal", activityType: statistic.workoutType?.prettyString ?? "DW SUP Foil")
                                }
                            }
                            
                        } header: {
                            if !filteredGroupedStatistics[yearIndex][monthIndex].isEmpty {
                                VStack(alignment: .leading) {
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
            }
        }
        .navigationTitle("Filter by Tags")
        
    }
    
    private func binding(for statistic: RunStatistic) -> Binding<RunStatistic> {
        guard let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statistic.id }) else {
            return .constant(RunStatistic.empty())
        }
        return $downwindManager.runStatistics[index]
    }
    
    private func monthSectionHeader(yearIndex: Int, monthIndex: Int) -> String {
        let month = Calendar.current.component(.month, from: filteredGroupedStatistics[yearIndex][monthIndex].first?.startDate ?? Date.distantPast)
        let monthName = Calendar.current.monthSymbols[month - 1]
        let year = Calendar.current.component(.year, from: filteredGroupedStatistics[yearIndex].first?.first?.startDate ?? Date.distantPast)
        let yearString = String(year)
        return monthName + " " + yearString
    }
}


#Preview {
    GroupedTagsListView(downwindManager: DownwindManager())
}
