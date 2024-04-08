//
//  StatisticsModelings.swift
//  7III Location
//
//  Created by Simon Lang on 25.03.2024.
//

import SwiftUI

struct StatisticsModelings: View {
    @ObservedObject var downwindManager: DownwindManager

    let strings: [String]
    
    var body: some View {
        // List with different statistics
        List {
            ForEach(strings.indices, id: \.self) { index in
                let statistic = downwindManager.testStatistics[index]
                let string = strings[index]
                NavigationLink {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: statistic)
                } label: {
                    RunOverView(runDate: string, runName: "", distance: makePrettyDistance(meters: statistic.runDistance, system: downwindManager.measurementSystem, statistics: true), time: "", averageSpeed: "")
                }
            }

            }
        
            .navigationTitle("Filter Modeling")
    }
}

//#Preview {
//    StatisticsModelings(downwindManager: DownwindManager(), statistic: <#RunStatistic#>)
//}
