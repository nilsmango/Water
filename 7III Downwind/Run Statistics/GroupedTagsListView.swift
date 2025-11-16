//
//  GroupedTagsListView.swift
//  7III Tracker
//
//  Created by Simon Lang on 21.06.2024.
//

import SwiftUI

struct GroupedTagsListView: View {
    @ObservedObject var downwindManager: DownwindManager
        
        init(downwindManager: DownwindManager) {
            self.downwindManager = downwindManager
            
            // Set the color for the page indicators
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.blackAndWhite
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.grayAndGray
        }
    
    @State private var chosenTags = [String]()
    @State private var chosenLocation = ""
    @State private var chosenWorkout = ""
    @State private var showOnlyAngles: Bool = false
    
    @State private var tabSelection: Tab = .tags
    
    private enum Tab {
        case tags, locations, workouts, options
        
        var prettyString: String {
            switch self {
            case .tags:
                return "Tags"
            case .locations:
                return "Locations"
            case .workouts:
                return "Workouts"
            case .options:
                return "Options"
            }
        }
    }
    
    var filteredGroupedStatistics: [[[RunStatistic]]] { downwindManager.filterGroupedStatistics(tags: chosenTags, location: chosenLocation, workout: chosenWorkout, onlyAngles: showOnlyAngles) }
    
    let maxHeight = UIScreen.main.bounds.height / 5
    
    
    
    var body: some View {
        // add a row of FlexibleView items that are buttons that will get added to the tags
        VStack {
            
            TabView(selection: $tabSelection) {
                
                ScrollView {
                    if downwindManager.tags.isEmpty {
                        Text("Add tags to workouts to display them here.")
                            .foregroundStyle(.secondary)
                    } else {
                        FlexibleView(
                            data: downwindManager.tags,
                            spacing: 5,
                            alignment: .leading
                        ) { string in
                            
                            SelectionButtonLabel(string: string, chosenStrings: $chosenTags)
                                .onTapGesture {
                                    if chosenTags.contains(string) {
                                        chosenTags.removeAll(where: { $0 == string})
                                    } else {
                                        chosenTags.append(string)
                                    }
                                }
                        }
                    }
                }
                 .frame(maxHeight: maxHeight)
                .padding([.bottom, .horizontal])
                .tag(Tab.tags)
                
                StringSelectionView(allStrings: downwindManager.locationStrings, chosenString: $chosenLocation, isLocations: true)
                    .frame(maxHeight: maxHeight)
                    .padding([.bottom])
                    .tag(Tab.locations)
                
                
                StringSelectionView(allStrings: downwindManager.getWorkoutsOfList(), chosenString: $chosenWorkout)
                    .frame(maxHeight: maxHeight)
                    .padding([.bottom])
                    .tag(Tab.workouts)
                
                
                List {
                    Toggle(isOn: $showOnlyAngles) {
                        Label("Only show sessions w/ angles", systemImage: "angle")
                    }
                    .tint(.accent)
                }
                .listStyle(.plain)
                .frame(maxHeight: maxHeight)
                .padding([.bottom])
                .tag(Tab.options)
                               
            }
            .frame(maxHeight: maxHeight + 60)
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
            .padding(.bottom, -10)
            
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
                                    RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeedString, kCal: "\(Int(statistic.kCalories?.rounded() ?? 0)) kcal", activityType: statistic.workoutType?.prettyString ?? "Surfing", withTags: true, tags: statistic.tags ?? [], withLocationAndAngle: true, location: statistic.locationString ?? "", withoutLocationSymbol: true, angle: downwindManager.calculateMaxAngle(angles: statistic.angles ?? []))
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
        .navigationTitle("\(tabSelection.prettyString)")
        .navigationBarTitleDisplayMode(.inline)
        
    }
    
    private func binding(for statistic: RunStatistic) -> Binding<RunStatistic> {
        guard let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statistic.id }) else {
            return .constant(RunStatistic.empty())
        }
        return $downwindManager.runStatistics[index]
    }
    
    private func monthSectionHeader(yearIndex: Int, monthIndex: Int) -> String {
        let monthComponent = filteredGroupedStatistics[yearIndex][monthIndex].first?.startDate
        var monthName = ""
        var yearString = ""
        if let monthComponent = monthComponent {
            let month = Calendar.current.component(.month, from: monthComponent)
            monthName = Calendar.current.monthSymbols[month - 1]
            let year = Calendar.current.component(.year, from: monthComponent)
            yearString = String(year)
        }
        
        return monthName + " " + yearString
    }
}


#Preview {
    NavigationStack {
        GroupedTagsListView(downwindManager: DownwindManager())
    }
}
