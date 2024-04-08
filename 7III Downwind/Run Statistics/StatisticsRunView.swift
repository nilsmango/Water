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
    let averageSpeed: String
    let runDates: String
    
    @State private var locationName: String = ""
    
    @State private var showRounds = false
    @State private var showMapSheet = false
    
    var body: some View {
        let cutDate = runDates.components(separatedBy: " ")
        let rounds = downwindManager.createRounds(for: statisticsData.locationData)
        
            List {
                Section {
                    StatisticsDetails(distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statisticsData.runTime), averageSpeed: averageSpeed, averagePace: downwindManager.calculateAveragePace(statistic: statisticsData), topSpeed: makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem))
                } header: {
                    VStack(alignment: .leading) {
                        Group {
                            Text(cutDate[0] + " " + cutDate[1])
                                .fontWeight(.bold)
                                .font(.title)
                                .padding(.bottom, -12)
                            Text(cutDate.dropFirst(2).joined(separator: " "))
                                .font(.body)
                        }
                        .padding(.bottom, 9)
                        
                        if locationName != "" {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.accent)
                                Text(locationName)
                            }
                            .textCase(nil)
                            .font(.body)
                            .padding(.bottom, 9)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                }
                .onAppear {
                    downwindManager.getNameOfLocation(location: statisticsData.locationData.first!) { name in
                        if let name = name {
                            locationName = name
                        }
                        downwindManager.getNameOfLocation(location: statisticsData.locationData.last!) { name in
                            if let name = name {
                                if locationName.contains("→") == false {
                                    locationName += " → " + name
                                }
                            }
                        }
                    }
                    
                }
                
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
                
                Section {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: statisticsData)
                        .frame(height: 300)
                        .cornerRadius(5.0)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    showMapSheet = true
                                }
                        )
                    
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
            .sheet(isPresented: $showRounds, content: {
                NavigationStack {
                    List {
                        StatisticsRounds(downwindManager: downwindManager, rounds: rounds)
                    }
                    .navigationTitle("Rounds")
                    .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showRounds = false
                                }, label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                })
                            }
                    }
                }
                
            })
            .sheet(isPresented: $showMapSheet, content: {
                ZStack {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: statisticsData)
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showMapSheet = false
                            }, label: {
                                Label("Close", systemImage: "xmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .gray)
                                    
                            })
                            .font(.title2)
                            .padding()
                        }
                        Spacer()
                    }
                }
                
            })
            .navigationTitle(statisticsData.runName)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StatisticsRunView(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 47, runDistance: 22900, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData), averageSpeed: "14.2 km/h", runDates: "Jan 03 13:12 - 13:59")
    }
}
