//
//  StatisticsEditView.swift
//  7III Tracker
//
//  Created by Simon Lang on 28.04.2024.
//

import SwiftUI

struct StatisticsEditView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var statisticsData: RunStatistic
    
    let padding = 16.0
    
    var body: some View {
//        VStack {
            StatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData, editMode: true)
//                .frame(width: UIScreen.main.bounds.width - padding * 2, height: UIScreen.main.bounds.height / 1.5)
//                .cornerRadius(16.0)
            
//            HStack {
//                Label("Select a point to edit", systemImage: "info.circle")
//                
//                Spacer()
//            }
//            .padding(padding)
//            
//            Spacer()
//        }
//        .padding()
    }
}

#Preview {
    NavigationStack {
        StatisticsEditView(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 47.1, runDistance: 22900, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: ["#140p", "#17kn"])))
            .navigationTitle("Edit Run Data")
            .navigationBarTitleDisplayMode(.inline)
    }
    
}
