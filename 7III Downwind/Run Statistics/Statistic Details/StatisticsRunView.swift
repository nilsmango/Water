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
    
    @State private var showStallStats = false
    @State private var stallEvents: [StallEvent] = []
    
    @State private var zoom: CGFloat = 1.0
    @State private var showAngleMap = false

    @State private var isCalculating = false
    @State private var calculationProgress = ""
    @State private var hasLoadedInitialData = false
    
    @State private var fastestDistances: [FastestDistanceResult]? = []
    @State private var rounds: [(String, String, String)] = []
    @State private var heartRateSpeedData: [SpeedSample] = []
    
    @AppStorage("hasTappedFastestDistance") var hasTappedDistance = false
    
    var body: some View {
        
        let cutDate = runDates.components(separatedBy: " ")
        
        List {
            Section {
                
                StatisticsDetails(distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true), time: makePrettyTime(timeInMinutes: statisticsData.runTime), averageSpeed: makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem), averagePace: downwindManager.calculateAveragePace(statistic: statisticsData), topSpeed: makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem), topsSpeed1s: makePrettySpeed(speed: statisticsData.topSpeed1s, system: downwindManager.measurementSystem), topsSpeed10s: makePrettySpeed(speed: statisticsData.topSpeed10s, system: downwindManager.measurementSystem), kCal: String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal", heartRate: String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm", popUps: statisticsData.popUps ?? 0, percentageOnFoil: statisticsData.percentageOnFoil ?? 0, turns: statisticsData.turnsCount ?? 0, longestDistanceOnFoil: makePrettyDistance(meters: statisticsData.longestDistanceOnFoil ?? 0, system: downwindManager.measurementSystem, statistics: true), fastestDistances: fastestDistances, hasTappedDistance: $hasTappedDistance)
            } header: {
                VStack(spacing: 0) {
                    StatisticsMainHeader(cutDate: cutDate, locationName: statisticsData.locationString ?? locationName, activity: statisticsData.workoutType?.prettyString ?? "Surfing")
                    
                    if isCalculating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(calculationProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                .foregroundStyle(.primary)
            } footer: {
                if !hasTappedDistance {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "info.circle")
                        Text("Tap any fastest distance to toggle between time and speed")
                    }
                }
            }
            .onAppear {
                
                if statisticsData.tags != nil {
                    tags = statisticsData.tags!
                }
                locationName = statisticsData.locationString ?? ""
                editLocationName = locationName
                
                guard !hasLoadedInitialData else {
                    return
                }
                
                Task.detached(priority: .background) {
                    await downwindManager.loadRouteAndHeartFromHealth(statistic: statisticsData) { _ in
                        Task { @MainActor in
                            await performBackgroundCalculations()
                        }
                    }
                }
                
                // if foil sport and no % on foil calculate and save the stats
                if statisticsData.percentageOnFoil ?? 0 == 0 ||
                    statisticsData.longestDistanceOnFoil ?? 0 == 0 {
                    
                    guard let workoutType = statisticsData.workoutType,
                          workoutType.calculateFoilingStats else { return }
                    
                    let locationData = statisticsData.locationData
                    let threshold = workoutType.thresholdSpeedKmhSlowSpeedWithDefault
                    let countTurns = workoutType.countTurns
                    let returnWaves = workoutType.returnWaves
                    let statsID = statisticsData.id
                    
                    Task.detached(priority: .utility) {
                        let foilStats = calculateFoilingStats(
                            from: locationData,
                            thresholdSpeedKmh: threshold,
                            countTurns: countTurns,
                            returnWaves: returnWaves
                        )
                        
                        guard foilStats != (0, 0, 0, 0, [[]]) else { return }
                        
                        await MainActor.run {
                            statisticsData.popUps = foilStats.popUps
                            statisticsData.percentageOnFoil = foilStats.timeOnFoilPercentage
                            statisticsData.turnsCount = foilStats.turns
                            statisticsData.longestDistanceOnFoil = foilStats.longestDistanceOnFoil
                            statisticsData.waves = foilStats.waves
                            
                            downwindManager.saveOnFoilStats(
                                popUps: foilStats.popUps,
                                percentageOnFoil: foilStats.timeOnFoilPercentage,
                                turns: foilStats.turns,
                                longestDistanceOnFoil: foilStats.longestDistanceOnFoil,
                                statisticsID: statsID,
                                waves: foilStats.waves
                            )
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
            
            if !statisticsData.locationData.isEmpty {
                MapSectionView(downwindManager: downwindManager, showRounds: $showRounds, showMapSheet: $showMapSheet, showAngleMap: $showAngleMap, rounds: rounds, statisticsData: $statisticsData)
                
                if statisticsData.angles?.count ?? 0 > 0 {
                    Section {
                        AngleSection(angles: statisticsData.angles!)
                    } header: {
                        HStack {
                            Text("Angles")
                                .textCase(nil)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button {
                                showAngleMap = true
                            } label: {
                                Label("Edit Angles", systemImage: "")
                            }
                            .textCase(nil)
                            .font(.body)
                            
                        }
                        .padding(.bottom, 9)
                        
                    }
                }
                
                HeartRateView(downwindManager: downwindManager, heartRates: heartRates, startDate: statisticsData.startDate, endDate: statisticsData.endDate, speedData: heartRateSpeedData)
                
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
                            editTags = tags
                            showTagsEditView = true
                            
                        } label: {
                            tags.isEmpty ? Label("Add Tags", systemImage: "") : Label("Edit Tags", systemImage: "")
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
            
                
                
        }
        .navigationTitle(statisticsData.runName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !showStallStats {
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
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                if showStallStats {
                    Button {
                        showStallStats.toggle()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                } else {
                    if statisticsData.locationData.count > 2 {
                        Menu {
                            Button(action: {
                                if downwindManager.hasPurchasedPremium || downwindManager.editCounter <= 4 {
                                    // update the edit data
                                    statisticsDataEdit = statisticsData
                                    showRunEditView = true
                                } else {
                                    showUpgradeSheet = true
                                }
                                
                            }, label: {
                                if downwindManager.hasPurchasedPremium || downwindManager.editCounter <= 4  {
                                    Text("Edit Route")
                                } else {
                                    Label("Edit Route", systemImage: "lock.fill")
                                }
                                
                            })
                            
                            Button(action: {
                                // update the edit data
                                editTags = tags
                                editType = statisticsData.workoutType ?? .surf
                                showEditData = true
                                
                            }, label: {
                                Text("Edit Data")
                            })
                            
                            if let workout = statisticsData.workoutType, workout.calculateFoilingStats {
                                NavigationLink(destination: FoilingThresholds()) {
                                    Text("Edit Threshold Speeds")
                                }
                            }
                            
                            if statisticsData.locationData.isEmpty == false {
                                Button {
                                    stallEvents = FoilStallDetector.detectAllStallSpeeds(from: statisticsData.locationData)
                                    showStallStats = true
                                } label: {
                                    Text("Calculate Stall Speeds")
                                }
                            }
                            
                            
                            
                        } label: {
                            Text("Edit")
                        }
                    } else {
                        Button(action: {
                            // update the edit data
                            editTags = tags
                            editType = statisticsData.workoutType ?? .surf
                            showEditData = true
                            
                        }, label: {
                            Text("Edit")
                        })
                    }
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
                                XMarkLabel()
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
                            XMarkLabel()
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
                        //                        WindSportStatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData)
                        SpeedGradientStatisticsMap(statisticsData: $statisticsData)
                            .ignoresSafeArea()
                    }
                }
                .navigationTitle(statisticsData.locationString ?? locationName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showMapSheet = false
                        }, label: {
                            XMarkLabel()
                        })
                    }
                }
            }
            
        })
    
        .sheet(isPresented: $showAngleMap, content: {
            NavigationStack {
                WindSportStatisticsMap(downwindManager: downwindManager, statisticsData: $statisticsData, angleTool: true)
                    .navigationTitle(statisticsData.locationString ?? locationName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showAngleMap = false
                            }, label: {
                                XMarkLabel()
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
                            downwindManager.editCounter += 1
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
                            XMarkLabel()
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
                                XMarkLabel()
                            })
                        }
                    }
            }
        })
    
        .overlay {
            if showStallStats {
                StallStatsOverlay(events: stallEvents, isPresented: $showStallStats)
                    .transition(.opacity)
            }
        }
        
    }
    
    private func performBackgroundCalculations() async {
        await MainActor.run {
            isCalculating = true
            calculationProgress = "Loading route data..."
            hasLoadedInitialData = true
        }
        
        await MainActor.run {
            calculationProgress = "Loading heart rate..."
        }
        
        let _ = await calculateTopSpeedsAsync()
        await MainActor.run {
            calculationProgress = "Analyzing foiling stats..."
        }
        let _ = await calculateFoilStatsAsync()
        await MainActor.run {
            calculationProgress = "Loading heart rates over time..."
        }
        await loadHeartRatesAsync()
        
        await MainActor.run {
            calculationProgress = "Creating location names..."
        }
        await createLocationNamesAsync()
        
        await MainActor.run {
            calculationProgress = "Fixing distance data..."
        }
        await fixDistanceAsync()
        
        await MainActor.run {
            calculationProgress = "Calculating fastest distances..."
        }
        await calculateFastestDistancesAsync()
        
        await MainActor.run {
            calculationProgress = "Calculating rounds..."
        }
        await calculateRoundsAsync()
        
        await MainActor.run {
            calculationProgress = "Processing speed data..."
        }
        await calculateSpeedDataAsync()
        
        await MainActor.run {
            isCalculating = false
            calculationProgress = ""
        }
    }
    
    private func calculateTopSpeedsAsync() async {
        guard (statisticsData.topSpeed1s ?? 0.0) == 0.0 || (statisticsData.topSpeed10s ?? 0.0) == 0.0 else {
            return
        }
        
        let topSpeeds = calculateTopSpeeds(from: statisticsData.locationData)
        await MainActor.run {
            statisticsData.topSpeed1s = topSpeeds.topSpeed1Sec
            statisticsData.topSpeed10s = topSpeeds.topSpeed10Sec
            downwindManager.saveTopSpeeds(speed1s: topSpeeds.topSpeed1Sec, speed10s: topSpeeds.topSpeed10Sec, statisticsID: statisticsData.id)
        }
    }
    
    private func calculateFoilStatsAsync() async {
        guard statisticsData.percentageOnFoil ?? 0 == 0 || statisticsData.longestDistanceOnFoil ?? 0 == 0 else {
            return
        }
        
        guard let workoutType = statisticsData.workoutType,
              workoutType.calculateFoilingStats else { return }
        
        let locationData = statisticsData.locationData
        let threshold = workoutType.thresholdSpeedKmhSlowSpeedWithDefault
        let countTurns = workoutType.countTurns
        let returnWaves = workoutType.returnWaves
        let statsID = statisticsData.id
        
        let foilStats = await Task.detached(priority: .utility) {
            calculateFoilingStats(
                from: locationData,
                thresholdSpeedKmh: threshold,
                countTurns: countTurns,
                returnWaves: returnWaves
            )
        }.value
        
        guard foilStats != (0, 0, 0, 0, [[]]) else { return }
        
        await MainActor.run {
            statisticsData.popUps = foilStats.popUps
            statisticsData.percentageOnFoil = foilStats.timeOnFoilPercentage
            statisticsData.turnsCount = foilStats.turns
            statisticsData.longestDistanceOnFoil = foilStats.longestDistanceOnFoil
            statisticsData.waves = foilStats.waves
            
            downwindManager.saveOnFoilStats(
                popUps: foilStats.popUps,
                percentageOnFoil: foilStats.timeOnFoilPercentage,
                turns: foilStats.turns,
                longestDistanceOnFoil: foilStats.longestDistanceOnFoil,
                statisticsID: statsID,
                waves: foilStats.waves
            )
        }
    }
    
    private func loadHeartRatesAsync() async {
        await withCheckedContinuation { continuation in
            downwindManager.fetchHeartRatesOverTime(statisticID: statisticsData.id, startTime: statisticsData.startDate, endTime: statisticsData.endDate) { heartRateData, _ in
                if let heartRateData = heartRateData {
                    Task { @MainActor in
                        heartRates = heartRateData
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func createLocationNamesAsync() async {
        guard statisticsData.locationString == nil || statisticsData.locationString == "" || statisticsData.locationString == "Unknown Location" else {
            return
        }
        
        await withCheckedContinuation { continuation in
            downwindManager.createLocationNames(statisticsData: statisticsData) { location in
                Task { @MainActor in
                    locationName = location
                    downwindManager.saveLocationString(string: locationName, statisticsID: statisticsData.id)
                    statisticsData.locationString = locationName
                    if let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statisticsData.id }) {
                        downwindManager.runStatistics[index].locationString = locationName
                        downwindManager.updateGroupedRunArray()
                    }
                    downwindManager.updateAndSortLocationStrings(location: location)
                    continuation.resume()
                }
            }
        }
    }
    
    private func fixDistanceAsync() async {
        guard !statisticsData.locationData.isEmpty && statisticsData.runDistance == 0.0 else {
            return
        }
        
        await MainActor.run {
            downwindManager.saveEditedRoute(newStatistic: statisticsData, updatingExternal: true)
        }
    }
    
    private func calculateFastestDistancesAsync() async {
        guard statisticsData.locationData.count > 2 else {
            return
        }
        
        let distances = await Task.detached(priority: .utility) {
            calculateFastestDistances(from: statisticsData.locationData, system: downwindManager.measurementSystem)
        }.value
        
        await MainActor.run {
            fastestDistances = distances
        }
    }
    
    private func calculateRoundsAsync() async {
        guard statisticsData.locationData.count > 2 else {
            return
        }
        
        let roundsResult = await Task.detached(priority: .utility) {
            downwindManager.createRounds(for: statisticsData.locationData)
        }.value
        
        await MainActor.run {
            rounds = roundsResult
        }
    }
    
    private func calculateSpeedDataAsync() async {
        guard statisticsData.locationData.count > 1 else {
            return
        }
        
        let speedDataResult = await Task.detached(priority: .utility) {
            createSpeedData(from: statisticsData.locationData)
        }.value
        
        await MainActor.run {
            heartRateSpeedData = speedDataResult
        }
    }
    
    private func createSpeedData(from locationData: [LocationData]) -> [SpeedSample] {
        guard locationData.count > 1 else { return [] }

        let targetSamples = 300

        let startTime = locationData.first!.timestamp
        let endTime   = locationData.last!.timestamp
        let duration  = endTime.timeIntervalSince(startTime)

        let bucketSize = max(duration / Double(targetSamples), 1)

        let grouped = Dictionary(grouping: locationData) { data in
            floor(data.timestamp.timeIntervalSince(startTime) / bucketSize)
        }

        return grouped.compactMap { (_, values) in
            let speeds = values.compactMap { $0.speed }
            guard !speeds.isEmpty else { return nil }

            let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)

            let midTime = values[0].timestamp.addingTimeInterval(bucketSize / 2)

            return SpeedSample(
                date: midTime,
                speedKmh: avgSpeed * 3.6
            )
        }
        .sorted { $0.date < $1.date }
    }
}

#Preview {
    NavigationStack {
        StatisticsRunView(downwindManager: DownwindManager(), statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: [])))
    }
}
