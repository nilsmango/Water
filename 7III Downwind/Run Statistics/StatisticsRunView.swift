//
//  StatisticsRunView.swift
//  7III Location
//
//  Created by Simon Lang on 07.04.2024.
//

import SwiftUI

struct StatisticsRunView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    let statisticsData: RunStatistic
    
    var body: some View {
            List {
                Section {
                    Text("Detailed run overview like in apple activies here")
                }
                
                Section {
                    StatisticsRounds(downwindManager: downwindManager, statisticsData: statisticsData)
                    
                }
                
                Text("Button to show sheet with whole map")
                Section {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: statisticsData)
                        .frame(height: 200)
                }
            }
    }
}

#Preview {
    StatisticsRunView(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData))
}
