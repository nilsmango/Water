//
//  StatisticsRunView.swift
//  7III Location
//
//  Created by Simon Lang on 07.04.2024.
//

import SwiftUI
import StoreKit

struct StatisticsRunView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var statisticsData: RunStatistic
    
    var runDates: String { downwindManager.makeTimeIntervalDate(startDate: statisticsData.startDate ?? statisticsData.locationData.first?.timestamp ?? Date.now, endDate: statisticsData.endDate ?? statisticsData.locationData.last?.timestamp ?? Date.now, withYear: true) }
    
    @State private var locationName: String = ""
    @State private var editLocationName: String = ""
    
    @State private var showRounds = false
    @State private var showMapSheet = false
    @State private var showTagsEditView = false
    @State private var showRunEditView = false
    @State private var showAlert = false
    @State private var showEditData = false
    @State private var showUpgradeSheet = false
    @State private var showShareSheet = false
    @State private var videoSharing = false
    @State private var showStickerSheet = false
    
    @State private var tags = [String]()
    @State private var editTags = [String]()
    @State private var editType: WorkoutType = .not7IIISurfingSport
    
    @State private var statisticsDataEdit = RunStatistic.empty()
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var heartRates: [Date: (Double, Double)] = [:]
    
    // trick for updating the map
    @State private var refreshPolyLines = false
    
    var body: some View {
        let cutDate = runDates.components(separatedBy: " ")
        let rounds = downwindManager.createRounds(for: statisticsData.locationData)
        
        List {
            Section {
                StatisticsDetails(distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statisticsData.runTime), averageSpeed: makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem), averagePace: downwindManager.calculateAveragePace(statistic: statisticsData), topSpeed: makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem), topsSpeed1s: makePrettySpeed(speed: statisticsData.topSpeed1s, system: downwindManager.measurementSystem), topsSpeed10s: makePrettySpeed(speed: statisticsData.topSpeed10s, system: downwindManager.measurementSystem), kCal: String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal", heartRate: String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm", popUps: statisticsData.popUps ?? 0, percentageOnFoil: statisticsData.percentageOnFoil ?? 0, turns: statisticsData.turnsCount ?? 0, longestDistanceOnFoil: makePrettyDistance(meters: statisticsData.longestDistanceOnFoil ?? 0, system: downwindManager.measurementSystem, statistics: true))
            } header: {
                StatisticsMainHeader(cutDate: cutDate, locationName: statisticsData.locationString ?? locationName, activity: statisticsData.workoutType?.prettyString ?? "Surfing")
            }
            
            if !statisticsData.locationData.isEmpty {
                MapSectionView(downwindManager: downwindManager, showRounds: $showRounds, showMapSheet: $showMapSheet, rounds: rounds, statisticsData: $statisticsData, refreshPolyLines: refreshPolyLines)
            }
            
                HeartRateView(downwindManager: downwindManager, heartRates: heartRates, startDate: statisticsData.startDate, endDate: statisticsData.endDate)
                
            
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
                            
                            Button() {
                                if downwindManager.hasPurchasedPremium {
                                    editTags = tags
                                    showTagsEditView = true
                                } else {
                                    showUpgradeSheet = true
                                }
                            } label: {
                                tags.isEmpty ? downwindManager.hasPurchasedPremium ? Label("Add Tags", systemImage: "") : Label("Add Tags", systemImage: "lock.fill") : downwindManager.hasPurchasedPremium ? Label("Edit Tags", systemImage: "") : Label("Edit Tags", systemImage: "lock.fill")
                            }
                            .textCase(nil)
                            .font(.body)
                            
                        }
                        .padding(.bottom, 9)
                        
                    } footer: {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                if downwindManager.hasPurchasedPremium {
                                    showAlert = true
                                } else {
                                    showUpgradeSheet = true
                                }
                            } label: {
                                Label("Delete Run", systemImage: downwindManager.hasPurchasedPremium ? "trash" : "lock.fill")
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                        }
                        .padding(.top, 32)
                    }
                
        }

        .onAppear {
            if statisticsData.tags != nil {
                tags = statisticsData.tags!
            }
            locationName = statisticsData.locationString ?? ""
            editLocationName = locationName
            print("on appear")
            downwindManager.loadRouteAndHeartFromHealth(statistic: statisticsData) { _ in
                print("got something from load route and heart from helth")
                // if empty create location start and end names after loading route
                if statisticsData.locationString == nil || statisticsData.locationString == "" || statisticsData.locationString == "Unknown Location" {
                    downwindManager.createLocationNames(statisticsData: statisticsData) { location in
                        locationName = location
                        DispatchQueue.main.async {
                            downwindManager.saveLocationString(string: locationName, statisticsID: statisticsData.id)
                            statisticsData.locationString = locationName
                            if let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statisticsData.id }) {
                                downwindManager.runStatistics[index].locationString = locationName
                                // update grouped array
                                downwindManager.updateGroupedRunArray()
                            }
                            // updating the locationStrings
                            downwindManager.updateAndSortLocationStrings(location: location)
                        }
                    }
                }
                // if no 10 s and 1 s top speed calculate and save those
                if (statisticsData.topSpeed1s ?? 0.0) == 0.0 || (statisticsData.topSpeed10s ?? 0.0) == 0.0 {
                    let topSpeeds = calculateTopSpeeds(from: statisticsData.locationData)
                    DispatchQueue.main.async {
                        statisticsData.topSpeed1s = topSpeeds.topSpeed1Sec
                        statisticsData.topSpeed10s = topSpeeds.topSpeed10Sec
                        downwindManager.saveTopSpeeds(speed1s: topSpeeds.topSpeed1Sec, speed10s: topSpeeds.topSpeed10Sec, statisticsID: statisticsData.id)
                    }
                }
                
                // if foil sport and no % on foil calculate and save the stats
                if statisticsData.percentageOnFoil ?? 0 == 0 || statisticsData.longestDistanceOnFoil ?? 0 == 0 {
                    print("Percentage on foil or longest distance on foil is 0")
                    if let workoutType = statisticsData.workoutType {
                        var foilStats: (popUps: Int, timeOnFoilPercentage: Double, turns: Int, longestDistanceOnFoil: Double) = (0, 0, 0, 0)
                            if workoutType.calculateFoilingStats {
                                foilStats = calculateFoilingStats(from: statisticsData.locationData, thresholdSpeedKmh: workoutType.thresholdSpeedKmhSlowSpeedWithDefault, countTurns: workoutType.countTurns)
                            }
                        if foilStats != (popUps: 0, timeOnFoilPercentage: 0, turns: 0, longestDistanceOnFoil: 0) {
                            DispatchQueue.main.async {
                                print("new pop ups: \(foilStats.popUps), percentage on foil: \(foilStats.timeOnFoilPercentage), turns: \(foilStats.turns), longest distance on foil: \(foilStats.longestDistanceOnFoil)")
                                statisticsData.popUps = foilStats.popUps
                                statisticsData.percentageOnFoil =  foilStats.timeOnFoilPercentage
                                statisticsData.turnsCount = foilStats.turns
                                statisticsData.longestDistanceOnFoil = foilStats.longestDistanceOnFoil
                                downwindManager.saveOnFoilStats(popUps: foilStats.popUps, percentageOnFoil: foilStats.timeOnFoilPercentage, turns: foilStats.turns, longestDistanceOnFoil: foilStats.longestDistanceOnFoil, statisticsID: statisticsData.id)
                            }
                        }
                    }
                }
                
                
                downwindManager.fetchHeartRatesOverTime(statisticID: statisticsData.id, startTime: statisticsData.startDate, endTime: statisticsData.endDate) { heartRateData, _  in
                    if let heartRateData = heartRateData {
                        heartRates = heartRateData
                    }
                }
                
                // update some things if we have location data but no distance
                if !statisticsData.locationData.isEmpty && statisticsData.runDistance == 0.0 {
                    DispatchQueue.main.async {
                        downwindManager.saveEditedRoute(newStatistic: statisticsData, updatingExternal: true)
                    }
                }
            }
            
        if downwindManager.showPromptForReview {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.73) {
                        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                    SKStoreReviewController.requestReview(in: scene)
                                }
                        downwindManager.showPromptForReview = false
                    
                }
            }
        }
        .navigationTitle(statisticsData.runName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                
                Menu {
                    Button {
                        videoSharing = true
                        showShareSheet = true
                    } label: {
                        Label("Video", systemImage: "film")
                    }
                    Button {
                        videoSharing = false
                        showShareSheet = true
                    } label: {
                        Label("Map Photo", systemImage: "photo")
                    }
                    Button {
                        showStickerSheet = true
                    } label: {
                        Label("Sticker Overlay", systemImage: "square.dashed")
                    }
                    
                    
                    GPXExportButton(locationData: statisticsData.locationData, activityName:  (statisticsData.locationString ?? locationName) + " " + makeStringFromDate(statisticsData.startDate ?? Date()), workoutType: statisticsData.workoutType ?? .surf)
                    
                    
                    
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                
                if statisticsData.locationData.count > 2 {
                    Menu {
                        Button(action: {
                            if downwindManager.hasPurchasedPremium {
                                // update the edit data
                                statisticsDataEdit = statisticsData
                                showRunEditView = true
                            } else {
                                showUpgradeSheet = true
                            }
                            
                        }, label: {
                            if downwindManager.hasPurchasedPremium {
                                Text("Edit Route")
                            } else {
                                Label("Edit Route", systemImage: "lock.fill")
                            }
                            
                        })
                        
                        Button(action: {
                            if downwindManager.hasPurchasedPremium {
                                // update the edit data
                                editTags = tags
                                editType = statisticsData.workoutType ?? .surf
                                showEditData = true
                            } else {
                                showUpgradeSheet = true
                            }
                        }, label: {
                            if downwindManager.hasPurchasedPremium {
                                Text("Edit Data")
                            } else {
                                Label("Edit Data", systemImage: "lock.fill")
                            }
                        })
                    } label: {
                        Text("Edit")
                    }
                } else {
                    Button(action: {
                        if downwindManager.hasPurchasedPremium {
                            // update the edit data
                            editTags = tags
                            editType = statisticsData.workoutType ?? .surf
                            showEditData = true
                        } else {
                            showUpgradeSheet = true
                        }
                    }, label: {
                        if downwindManager.hasPurchasedPremium {
                            Text("Edit")
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                Text("Edit")
                            }
                        }
                    })
                }
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
        
        .sheet(isPresented: $showUpgradeSheet, content: {
            NavigationStack {
                UpgradeView(downwindManager: downwindManager, showUpgradeView: $showUpgradeSheet)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showUpgradeSheet = false
                            } label: {
                                Label("Close", systemImage: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .gray)
                            }
                        }
                    }
            }
        })
        
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
            NavigationStack {
                Group {
                    if let dW = statisticsData.workoutType?.isDWSport, dW == true {
                        StatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData)
                    } else {
                        WindSportStatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData)
                    }
                }
                        .navigationTitle(statisticsData.locationString ?? locationName)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showMapSheet = false
                                }, label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                })
                            }
                }
            }
            
        })
        .sheet(isPresented: $showTagsEditView, content: {
            NavigationStack {
                List {
                    TagsEditView(tags: $editTags, downwindManager: downwindManager, type: .constant(.windsurf), locationString: .constant(""))
                }
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
                            downwindManager.saveStatisticWithNewTags(tags: tags, type: editType, saveType: false, statisticsData: statisticsData)
                            showTagsEditView = false
                        }, label: {
                            Text("Save")
                        })
                        .disabled(tags == editTags)
                    }
                }
            }
        })
        .sheet(isPresented: $showEditData, content: {
            NavigationStack {
                List {
                    TagsEditView(tags: $editTags, downwindManager: downwindManager, type: $editType, locationString: $editLocationName, withTypeEdit: true)
                }
                .navigationTitle("Edit Data")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive, action: {
                            showEditData = false
                        }, label: {
                            Text("Cancel")
                        })
                        .tint(.red)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            tags = editTags
                            locationName = editLocationName
                            statisticsData.locationString = editLocationName
                            downwindManager.saveStatisticWithNewTags(tags: tags, type: editType, saveType: true, statisticsData: statisticsData, locationName: editLocationName)
                            showEditData = false
                        }, label: {
                            Text("Save")
                        })
                        .disabled(tags == editTags && statisticsData.workoutType == editType && editLocationName == locationName)
                    }
                }
            }
        })
        .sheet(isPresented: $showRunEditView, content: {
            NavigationStack {
                    EditMap(downwindManager: downwindManager, statisticsData: $statisticsDataEdit)
                    .navigationTitle("Edit Route")
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
                                
                                showRunEditView = false
                                
                                downwindManager.saveEditedRoute(newStatistic: statisticsDataEdit)
                                
                                refreshPolyLines.toggle()
                                
                            }, label: {
                                Text("Save")
                            })
                        }
                    }
            }
        })
        
        .fullScreenCover(isPresented: $showShareSheet, content: {
            NavigationStack {
                Group {
                    if videoSharing {
                        VideoOverlayView(downwindManager: downwindManager, statisticsData: statisticsData)
                    } else {
                        ShareStatisticsView(downwindManager: downwindManager, statisticsData: statisticsData)
                    }
                }
                .navigationTitle(videoSharing ? "Share Video" : "Share Photo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                showShareSheet = false
                            }, label: {
                                Label("Close", systemImage: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .gray)
                            })
                        }
                    }
            }
        })
        
        .fullScreenCover(isPresented: $showStickerSheet, content: {
            NavigationStack {
                    RouteSticker(downwindManager: downwindManager, statisticsData: statisticsData)
                
                .navigationTitle("Create Sticker")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                showStickerSheet = false
                            }, label: {
                                Label("Close", systemImage: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .gray)
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
