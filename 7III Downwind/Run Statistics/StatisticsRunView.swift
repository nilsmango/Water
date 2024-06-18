//
//  StatisticsRunView.swift
//  7III Location
//
//  Created by Simon Lang on 07.04.2024.
//

import SwiftUI

struct StatisticsRunView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var statisticsData: RunStatistic
        
    var averageSpeed: String { makePrettySpeed(speed: (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) }
    
    var runDates: String { downwindManager.makeTimeIntervalDate(startDate: statisticsData.startDate ?? statisticsData.locationData.first?.timestamp ?? Date.now, endDate: statisticsData.endDate ?? statisticsData.locationData.last?.timestamp ?? Date.now, withYear: true) }
    
    @State private var locationName: String = ""
    
    @State private var showRounds = false
    @State private var showMapSheet = false
    @State private var showTagsEditView = false
    @State private var showRunEditView = false
    @State private var showAlert = false
    
    @State private var tags = [String]()
    @State private var editTags = [String]()
    
    @State private var statisticsDataEdit = RunStatistic.empty()
    
    @Environment(\.dismiss) private var dismiss

    
    var body: some View {
        let cutDate = runDates.components(separatedBy: " ")
        let rounds = downwindManager.createRounds(for: statisticsData.locationData)
        
        List {
            Section {
                StatisticsDetails(distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statisticsData.runTime), averageSpeed: averageSpeed, averagePace: downwindManager.calculateAveragePace(statistic: statisticsData), topSpeed: makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem), kCal: String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal", heartRate: String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm")
            } header: {
                StatisticsMainHeader(cutDate: cutDate, locationName: locationName)
            }
            .onAppear {
                if statisticsData.tags != nil {
                    tags = statisticsData.tags!
                }
                
                downwindManager.loadRouteAndHeartFromHealth(statistic: statisticsData) { _ in
                    // create location start and end names after loading route
                        if let firstDataPoint = statisticsData.locationData.first {
                            downwindManager.getNameOfLocation(location: firstDataPoint) { name in
                                if let name = name {
                                    locationName = name
                                }
                                
                                if let lastDataPoint = statisticsData.locationData.last {
                                    downwindManager.getNameOfLocation(location: lastDataPoint) { name in
                                        if let name = name {
                                            if locationName.contains("→") == false && locationName != name {
                                                locationName += " → " + name
                                            }
                                        }
                                    }
                                }
                                
                            }
                        }
                    
                    }
            }
            
            if !statisticsData.locationData.isEmpty {
                MapSectionView(downwindManager: downwindManager, showRounds: $showRounds, showMapSheet: $showMapSheet, rounds: rounds, statisticsData: $statisticsData)
            }
            
            HeartRateView(downwindManager: downwindManager, startDate: statisticsData.startDate, endDate: statisticsData.endDate)
                
            
                    Section {
                        TagsFlexiView(strings: tags)
                        
                    } header: {
                        HStack {
                            Text("Tags")
                                .textCase(nil)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            
                            Button(tags.isEmpty ? "Add Tags" : "Edit Tags") {
                                editTags = tags
                                showTagsEditView = true
                            }
                            .textCase(nil)
                            .font(.body)
                            
                        }
                        .padding(.bottom, 9)
                        
                    } footer: {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                showAlert = true
                            } label: {
                                Label("Delete Run", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                        }
                        .padding(.top, 32)
                    }
                
        }

        .navigationTitle(statisticsData.runName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // update the edit data
                    statisticsDataEdit = statisticsData
                    showRunEditView = true
                }, label: {
                    Text("Edit Data")
                })
            }
        }
        
        .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Are you sure?"),
                            message: Text("This will also delete the workout from Health."),
                            primaryButton: .destructive(Text("Delete")) {
                                dismiss()
                                downwindManager.deleteWorkout(id: statisticsData.id)
                            },
                            secondaryButton: .cancel()
                        )
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
                StatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData)
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
        .sheet(isPresented: $showTagsEditView, content: {
            NavigationStack {
                List {
                    TagsEditView(tags: $editTags, downwindManager: downwindManager)
                }
                .navigationTitle("Edit Tags")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive, action: {
                            showTagsEditView = false
                        }, label: {
                            Text("Cancel")
                        })
                        .tint(.red)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            tags = editTags
                            downwindManager.saveStatisticWithNewTags(tags: tags, statisticsData: statisticsData)
                            showTagsEditView = false
                        }, label: {
                            Text("Save")
                        })
                        .disabled(tags == editTags)
                    }
                }
            }
            
        })
        .sheet(isPresented: $showRunEditView, content: {
            NavigationStack {
                StatisticsEditView(downwindManager: downwindManager, statisticsData: $statisticsDataEdit)
                    .navigationTitle("Edit Run Data")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(role: .destructive, action: {
                                showRunEditView = false
                            }, label: {
                                Text("Cancel")
                            })
                            .tint(.red)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                // update the binding
                                statisticsData = statisticsDataEdit
                                
                                showRunEditView = false
                                
                                // TODO: save the new data
//                                downwindManager.saveEditedRoute(statistic: statisticsData)
                                
                            }, label: {
                                Text("Save")
                            })
                        }
                    }
            }
        })
    }
}

#Preview {
    NavigationStack {
        StatisticsRunView(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: [])))
    }
}
