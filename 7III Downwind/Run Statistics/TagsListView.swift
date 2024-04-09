//
//  TagsListView.swift
//  7III Location
//
//  Created by Simon Lang on 09.04.2024.
//

import SwiftUI

struct TagsListView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var chosenTags = [String]()
    
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
                ForEach(downwindManager.filterStatistics(tags: chosenTags)) { statistic in
                    let averageSpeed = makePrettySpeed(speed: (statistic.runDistance / 1000) / (statistic.runTime / 60), system: downwindManager.measurementSystem)
                    let runDates = downwindManager.makeTimeIntervalDate(startDate: statistic.locationData.first!.timestamp, endDate: statistic.locationData.last!.timestamp)
                    
                    NavigationLink {
                        StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic, averageSpeed: averageSpeed, runDates: runDates)
                    } label: {
                        RunOverView(runDate: runDates, runName: statistic.runName, distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statistic.runTime), averageSpeed: averageSpeed)
                    }
                }
            }
        }
        .navigationTitle("Filter by Tags")
    }
}

#Preview {
    NavigationStack {
        TagsListView(downwindManager: DownwindManager())
    }
}
