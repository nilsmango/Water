//
//  StatisticsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

struct StatisticsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var showUpgradeSheet = false
    
    @State private var showMonths: Bool = true
    
    @State private var showYear: [Bool] = Array(repeating: true, count: 100)
    
    var body: some View {
        List {
                if downwindManager.loadingRunStatistics {
                    Section {
                        
                    } header: {
                        HStack {
                            Spacer()
                            ProgressView("Loading Statistics")
                            Spacer()
                        }
                    }
                    .textCase(nil)
                }
                    
                    ForEach(0..<downwindManager.groupedRunStatistics.count, id: \.self) { yearIndex in
                        ForEach(0..<downwindManager.groupedRunStatistics[yearIndex].count, id: \.self) { monthIndex in
                            
                            if monthIndex == 0 {
                                Section {
                                    YearlyMonthlyStatisticView(downwindManager: downwindManager, yearIndex: yearIndex)
                                } header: {
                                    HStack {
                                        Text(yearSectionHeader(yearIndex: yearIndex))
                                            .font(.title)
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
                                            
                                            Button {
                                                showYear[yearIndex].toggle()
                                            } label: {
                                                if showYear[yearIndex] {
                                                    Label("Hide Months", systemImage: "chevron.down")
                                                } else {
                                                    Label("Show Months", systemImage: "chevron.right")
                                                }
                                            }
                                            .fontWeight(.semibold)
                                            .labelStyle(.iconOnly)
                                            
                                        
                                    }
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                }
                            }
                            
                            if showMonths && showYear[yearIndex] {
                                Section {
                                    YearlyMonthlyStatisticView(downwindManager: downwindManager, yearIndex: yearIndex, monthIndex: monthIndex)
                                } header: {
                                    VStack(alignment: .leading) {
                                        Text(monthSectionHeader(yearIndex: yearIndex, monthIndex: monthIndex))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                }
                                
                                Section {
                                    ForEach(downwindManager.groupedRunStatistics[yearIndex][monthIndex]) { statistic in
                                        
                                        let averageSpeedString = makePrettySpeed(speed: statistic.averageSpeed ?? (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                                        let runDates = downwindManager.makeTimeIntervalDate(startDate: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.now, endDate: statistic.endDate ?? statistic.locationData.last?.timestamp ?? Date.now)
                                        
                                        NavigationLink {
                                            StatisticsRunView(downwindManager: downwindManager, statisticsData: binding(for: statistic))
                                        } label: {
                                            RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeedString, kCal: "\(Int(statistic.kCalories?.rounded() ?? 0)) kcal", activityType: statistic.workoutType?.prettyString ?? "DW SUP Foil", withTags: true, tags: statistic.tags ?? [], withLocationAndAngle: true, location: statistic.locationString ?? "", withoutLocationSymbol: true, angle: downwindManager.calculateMaxAngle(angles: statistic.angles ?? []))
                                        }
                                    }
                                } footer: {
                                    if downwindManager.statisticsCount > 5, downwindManager.hasPurchasedPremium == false {
                                        HStack {
                                            Spacer()
                                            Button {
                                                showUpgradeSheet = true
                                            } label: {
                                                Label("Load \(downwindManager.statisticsCount - 5) more Sessions", systemImage: "lock.fill")
                                            }
                                            .buttonStyle(.borderedProminent)
                                            Spacer()
                                        }
                                        .padding(.top, 32)
                                        .padding(.bottom, 32)
                                    }
                                }
                            }
                        }
                    }
                }
            
            .refreshable {
                // Reload both statistic arrays
                if !downwindManager.loadingRunStatistics {
                    downwindManager.loadRunStatistics()
                }
                
            }
            .sheet(isPresented: $showUpgradeSheet, content: {
                NavigationStack {
                    UpgradeView(downwindManager: downwindManager, showUpgradeView: $showUpgradeSheet)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showUpgradeSheet = false
                                } label: {
                                    XMarkLabel()
                                }
                            }
                        }
                }
            })
        .navigationTitle("Statistics")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMonths.toggle()
                } label: {
                    if showMonths {
                        Label("Hide Details", systemImage: "chevron.down")
                    } else {
                        Label("Show Details", systemImage: "chevron.right")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Filter") {
                    GroupedTagsListView(downwindManager: downwindManager)
                }
            }
        }
    }
    
    private func binding(for statistic: RunStatistic) -> Binding<RunStatistic> {
        guard let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statistic.id }) else {
            return .constant(RunStatistic.empty())
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
