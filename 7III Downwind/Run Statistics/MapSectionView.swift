//
//  MapSectionView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI

struct MapSectionView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showRounds: Bool
    @Binding var showMapSheet: Bool
    
    let rounds: [(String, String, String)]
    @Binding var statisticsData: RunStatistic
    
    var body: some View {
        if statisticsData.runDistance > 1999 {
            Section {
                StatisticsRounds(downwindManager: downwindManager, rounds: rounds, overViewLayout: true)
                
            } header: {
                HStack {
                    Text("Rounds")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Show all") {
                        showRounds = true
                    }
                    .textCase(nil)
                    .font(.body)
                }
                .padding(.bottom, 9)
            }
        }
        
        
        Section {
            Button {
                showMapSheet = true
            } label: {
                // sometimes the map does not update, so I try this trick.
                let mapData = statisticsData
                StatisticsMap(downwindManager: downwindManager, statisticsData: .constant(mapData))
                    .frame(height: 300)
                    .cornerRadius(5.0)
                    .disabled(true)
            }
            
        } header: {
            HStack {
                Text("Map")
                    .textCase(nil)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Show more") {
                    showMapSheet = true
                }
                .textCase(nil)
                .font(.body)
            }
            .padding(.bottom, 9)
        }
    }
}

#Preview {
    List {
        MapSectionView(downwindManager: DownwindManager(), showRounds: .constant(false), showMapSheet: .constant(false), rounds: [], statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: [])))
    }
}
