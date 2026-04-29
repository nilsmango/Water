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
    @Binding var showAngleMap: Bool
    
    let rounds: [(String, String, String)]
    let flights: [(String, String, String, String)]
    @Binding var statisticsData: RunStatistic
    
    var body: some View {
        let showsFlights = statisticsData.workoutType?.returnWaves == true
        let showsSegmentSection = showsFlights ? !flights.isEmpty : statisticsData.runDistance > 1999

        if showsSegmentSection {
            Section {
                if showsFlights {
                    StatisticsFlights(downwindManager: downwindManager, flights: flights, overViewLayout: true)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showRounds = true
                        }
                } else {
                    StatisticsRounds(downwindManager: downwindManager, rounds: rounds, overViewLayout: true)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showRounds = true
                        }
                }
            } header: {
                HStack {
                    Text(showsFlights ? "Flights" : "Rounds")
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
            .id(showsFlights ? "flights" : "rounds")
        }
        
        
        Section {
            Button {
                showMapSheet = true
            } label: {
                if let dW = statisticsData.workoutType?.isDWSport, dW == true {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData)
                        .frame(height: 300)
                        .cornerRadius(8.0)
                        .disabled(true)
                } else {
                    SpeedGradientStatisticsMap(statisticsData: $statisticsData, lineWidth: 1.5)
                        .frame(height: 300)
                        .cornerRadius(8.0)
                        .disabled(true)
                }
            }
            .id("map")
            
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
        } footer: {
            if statisticsData.workoutType?.angleSport == true && statisticsData.angles?.count ?? 0 < 1 {
                HStack {
                    Spacer()
                    Button {
                        showAngleMap = true
                    } label: {
                        Label("Measure Angles", systemImage: "angle")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                    Spacer()
                }
                .padding(.bottom, 9)
                .id("measureAngles")
            }
        }
    }
}

#Preview {
    List {
        MapSectionView(downwindManager: DownwindManager(), showRounds: .constant(false), showMapSheet: .constant(false), showAngleMap: .constant(false), rounds: [], flights: [], statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: [])))
    }
}
