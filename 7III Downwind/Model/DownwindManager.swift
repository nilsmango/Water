//
//  DownwindManager.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI
import Combine
import CoreLocation
import _MapKit_SwiftUI
#if os(iOS)
import KeychainSwift
import HealthKit
#endif
import StoreKit
import XMLCoder

typealias Transaction = StoreKit.Transaction

public enum StoreError: Error {
    case failedVerification
}

enum FakeDataExportError: LocalizedError {
    case noHealthKitData
    case noRunsFound(year: Int)
    case noExportableRuns(year: Int)

    var errorDescription: String? {
        switch self {
        case .noHealthKitData:
            return "HealthKit data is not available on this device."
        case .noRunsFound(let year):
            return "No supported workouts were found for \(year)."
        case .noExportableRuns(let year):
            return "Workouts were found for \(year), but none had route data that could be exported."
        }
    }
}

struct ScreenshotFeaturedRuns: Codable {
    var angleRunID: UUID?
    var exportRunID: UUID?
    var tagsRunID: UUID?
    var placesRunID: UUID?
    var statsDetailRunID: UUID?
    var parawingRunID: UUID?
    var upDownwindParawingRunID: UUID?
    var mapRunID: UUID?
    var homeRunID: UUID?
    var queuedImportRunIDs: [UUID] = []
    var highlightedTags: [String] = []
    var highlightedPlaces: [String] = []
}

struct ScreenshotFakeDataBundle: Codable {
    var sourceYear: Int
    var exportedAt: Date
    var importRuns: [ImportRun]
    var queuedImportRuns: [ImportRun]
    var runEdits: [RunEdit]
    var dashboards: [Dashboard]
    var widgetDashboardIds: [UUID]
    var featured: ScreenshotFeaturedRuns
}

class DownwindManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - App Storage and Init
    #if os(iOS)
    @AppStorage("runListSorting") var runListSorting: RunListSorting = .distanceAscending
    @AppStorage("showListDetail") var showListDetail: Bool = true
    @AppStorage("showGPXImport") var showGPXImport: Bool = true
    @AppStorage("showMaps") var showMaps: Bool = true
    @AppStorage("showTracker") var showTracker: Bool = true
    @AppStorage("measurementSystem") var measurementSystem: MeasurementSystem = .metric
    @AppStorage("workoutType") var workoutType: WorkoutType = .downwindSUPFoil
        
    @AppStorage("workoutUsageCount") private var workoutUsageCountData: Data = Data()
    
    var workoutUsageCount: [WorkoutType: Int] {
        get {
            if let decodedCounts = try? JSONDecoder().decode([WorkoutType: Int].self, from: workoutUsageCountData) {
                return decodedCounts
            } else {
                return [:]
            }
        }
        set {
            if let encodedCounts = try? JSONEncoder().encode(newValue) {
                workoutUsageCountData = encodedCounts
            }
        }
    }
    
    private func incrementWorkoutCount(for type: WorkoutType) {
        workoutUsageCount[type, default: 0] += 1
    }
    #endif
    override init() {
        super.init()
        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()
        
        appOpened += 1
        
        Task {
            // During store initialization, request products from the App Store.
            await loadProductIdentifiersAndRequestProducts()
            
            await updateCustomerProductStatus()
        }
        #if os(iOS)
        loadTags()
        
        setupLocationManager()
        #endif
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
#if os(iOS)
    // MARK: - Tags
    
    @AppStorage("statisticTags") private var tagsData: Data = Data()
    
    private func saveTags() {
        if let encodedTags = try? JSONEncoder().encode(tags) {
            tagsData = encodedTags
        }
    }
    
    private func loadTags() {
        if let decodedTags = try? JSONDecoder().decode([String].self, from: tagsData) {
            tags = decodedTags
        }
    }
    
    @Published var tags: [String] = []
    
    
    // MARK: - Statistics
    /// showing if gps statistic tracking is on
    @Published var activeStatistics: Bool = false
    @Published var runStatistics: [RunStatistic] = []
    @Published var loadingRunStatistics = false
    var runEdits: [RunEdit] = []
    @Published var groupedRunStatistics: [[[RunStatistic]]] = []
    @Published var locationStrings: [String] = []

    // TODO: make this non published?
    @Published var locationAccuracy: Double = 1000.0
    // summary view
    @Published var workout: HKWorkout?
    @Published var showingSummarySheet = false
    var currentRunStatisticIndex = 0
    var routeBuilder: HKWorkoutRouteBuilder? = nil
    var workoutBuilder: HKWorkoutBuilder? = nil
    
    /// backup to health
    var backupWorkoutData = [RunStatistic]()
    private var latestStatisticLocationData: LocationData?
    
    /// Activates the run statistic tracking (only tracking)
    func startStatistic(tags: [String] = []) {
        // update the workout usage count
        incrementWorkoutCount(for: workoutType)
        
        // Safety first
        if !activeStatistics {
            activeStatistics = true
            
            // start location tracking if we have not done that
            checkAndStartLocationService(cloudService: false)
            
            // create a new RunStatistic and record the first point to the runStatistic
            // map the member names
            // TODO: this should get saved to health again one day maybe
            let crewStatistics = activeRun.members.compactMap { member -> CrewStatistic? in
                // ignore members that are only watching
                if member.onlyWatching == false {
                    var statisticData: [LocationData] = []
                    if let latitude = member.latitude, let longitude = member.longitude {
                        statisticData = [LocationData(timestamp: Date.now, latitude: latitude, longitude: longitude)]
                    }
                    return CrewStatistic(memberID: member.id, memberName: member.name, locationData: statisticData)
                } else {
                    return nil
                }
            }
            
            // make the first data entry if there is a location
            let currentLocationData = currentStatisticLocationData()
            var newStatistic: RunStatistic
            if let currentLocationData {
                newStatistic = RunStatistic(id: UUID(), runName: activeRun.name, crewStatistics: crewStatistics, runTime: 0.0, runDistance: 0.0, topSpeed: (user.speed ?? 0.0) * 3.6, locationData: [currentLocationData], tags: tags)
            } else {
                newStatistic = RunStatistic(id: UUID(), runName: activeRun.name, crewStatistics: crewStatistics, runTime: 0.0, runDistance: 0.0, topSpeed: (user.speed ?? 0.0) * 3.6, locationData: [], tags: tags)
            }
            
            newStatistic.workoutType = workoutType
            let startDate = Date.now
            newStatistic.startDate = startDate
            runStatistics.append(newStatistic)
            currentRunStatisticIndex = runStatistics.endIndex - 1
            
                if HKHealthStore.isHealthDataAvailable() {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = workoutType.activityType
                    configuration.locationType = .outdoor
                    
                    workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
                    workoutBuilder?.beginCollection(withStart: startDate, completion: { _, _ in
                        // starting
                    })
                    routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
                }
            
        } else {
                // find current statistic and set runTime and run distance and run speed to now and zero
                runStatistics[currentRunStatisticIndex].runTime = 0.0
                runStatistics[currentRunStatisticIndex].runDistance = 0.0
                runStatistics[currentRunStatisticIndex].topSpeed = (user.speed ?? 0.0) * 3.6
                if let currentLocationData = currentStatisticLocationData() {
                    runStatistics[currentRunStatisticIndex].locationData = [currentLocationData]
                } else {
                    runStatistics[currentRunStatisticIndex].locationData = []
                }
                runStatistics[currentRunStatisticIndex].tags = tags
            let startDate = Date.now
            runStatistics[currentRunStatisticIndex].startDate = startDate
                runStatistics[currentRunStatisticIndex].workoutType = workoutType
                
                // start health kit workout and route builders
                if HKHealthStore.isHealthDataAvailable() {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = workoutType.activityType
                    configuration.locationType = .outdoor
                    
                    workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
                    workoutBuilder?.beginCollection(withStart: startDate, completion: { _, _ in
                        // starting
                    })
                    
                    routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
                }
        }
    }
    
    /// Stops the current run statistic
    func stopStatistic() {
        // Safety first
        if activeStatistics {
            // record one last point to the runStatistic
            updateStatistic()
            // deactivate statistic recording
            activeStatistics = false
            // save endDate
            runStatistics[currentRunStatisticIndex].endDate = Date.now
            
            // saving the workout
            if HKHealthStore.isHealthDataAvailable() {
                saveWorkoutToHealthBackup()
                saveHealthWorkout()
            } else {
                // save the statistics to disk if we don't have health available
                saveRunStatistics()
                // only stop location when we don't have a loacation sharing still active
                if !activeRun.active {
                    // Stop location update
                    stopLocationService()
                }
            }
            
            
        }
    }    
    
    private func saveWorkoutToHealthBackup() {
        let activeRunStatistic = runStatistics[currentRunStatisticIndex]
        backupWorkoutData.append(activeRunStatistic)
        saveBackupWorkoutDataToDisk()
    }
    
    private func saveHealthWorkout() {
        showingSummarySheet = true
        
        // Log potential data quality issues but don't prevent saving
        if currentRunStatisticIndex >= runStatistics.count {
            logError("Invalid currentRunStatisticIndex: \(currentRunStatisticIndex), array count: \(runStatistics.count)")
        }
        
        let activeRunStatistic = runStatistics[currentRunStatisticIndex]
        
        if activeRunStatistic.runDistance <= 0 {
            logError("Warning: run distance is \(activeRunStatistic.runDistance) meters")
        }
        
        if let avgSpeed = activeRunStatistic.averageSpeed, avgSpeed < 0 {
            logError("Warning: average speed is negative: \(avgSpeed)")
        }
        
        if activeRunStatistic.topSpeed < 0 {
            logError("Warning: top speed is negative: \(activeRunStatistic.topSpeed)")
        }
        
        if workoutBuilder == nil {
            logError("Cannot save workout - workoutBuilder is nil")
        }
        
        let runDistance = HKQuantity(unit: .meter(), doubleValue: activeRunStatistic.runDistance)
        let topSpeed = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: activeRunStatistic.topSpeed / 3.6)
        let averageSpeed = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: (activeRunStatistic.averageSpeed ?? 0) / 3.6)
        let tags = activeRunStatistic.tags?.joined(separator: " ") ?? ""
        let workoutType = activeRunStatistic.workoutType ?? .surfingSport
        
        let allMetadata: [String: Any] = [
            Constants.customMetadataKeyWorkoutType: workoutType.rawValue,
            Constants.customMetadataKeyTags: tags,
            Constants.customTotalDistanceKey: runDistance,
            HKMetadataKeyMaximumSpeed: topSpeed,
            HKMetadataKeyAverageSpeed: averageSpeed
        ]
        
        // Request background time for iOS
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Saving workout route") {
            // Expiration handler
            print("⚠️ Background time expired before route saved")
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        workoutBuilder?.addMetadata(allMetadata, completion: { success, error in
            if let error = error {
                self.logError("Error adding metadata: \(error.localizedDescription)")
            }
            
            if !success {
                self.logError("Adding metadata returned false")
            }
            
            self.workoutBuilder?.endCollection(withEnd: Date.now, completion: { success, error in
                
                if let error = error {
                    self.logError("Error ending workout collection: \(error.localizedDescription)")
                }
                
                if !success {
                    self.logError("End collection returned false")
                }
                
                self.workoutBuilder?.finishWorkout(completion: { workout, error in
                    if let error = error {
                        self.logError("Error finishing workout: \(error.localizedDescription)")
                    }
                    
                    if workout == nil {
                        self.logError("Finish workout returned nil workout")
                    }
                    
                    if let myWorkout = workout {
                        if self.routeBuilder == nil {
                            self.logError("Cannot finish route - routeBuilder is nil")
                        }
                        
                        self.routeBuilder?.finishRoute(with: myWorkout, metadata: nil) { [self] newRoute, error in
                            
                            if let error = error {
                                self.logError("Error finishing route: \(error.localizedDescription)")
                            }
                            
                            if newRoute == nil {
                                self.logError("Failed to finish route.")
                            }
                            
                            // Optional: Do something with the route here
                            print("Successfully saved workout and route to HealthKit.")
                            
                            // only now stop location to keep iphone active
                            DispatchQueue.main.async {
                                if !self.activeRun.active {
                                    // Stop location update
                                    self.stopLocationService()
                                }
                            }
                            // End background task AFTER everything completes
                            if backgroundTaskID != .invalid {
                                                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                                                        backgroundTaskID = .invalid
                                                    }
                            
                            // Discard the routeBuilder and workoutBuilder
                            self.routeBuilder = nil
                            self.workoutBuilder = nil
                            
                            
                            // Reload both statistic arrays
                            DispatchQueue.main.async {
                                self.workout = workout
                                self.loadRunStatistics()
                                
                                
                                // update and save the tracker sessions count
                                self.trackerSessionsCount += 1
                                let sessionsLeft = self.freeTrackerSessionsNumber - self.trackerSessionsCount
                                if sessionsLeft == -5 {
                                    if !SKPaymentQueue.canMakePayments() {
                                        self.logError("Cannot make payments - SKPaymentQueue unavailable")
                                    } else if !self.hasPurchasedPremium {
                                        self.showUpgradeSheet = true
                                    }
                                }
                                // if not yet asked ask every 10th session for a review.
                                if sessionsLeft == 0 || (sessionsLeft < 0 && sessionsLeft % 10 == 0) {
                                    if self.currentAppVersion != self.lastVersionPromptedForReview {
                                        self.showPromptForReview = true
                                        // The app already displayed the rating and review request view. Store this current version.
                                        self.lastVersionPromptedForReview = self.currentAppVersion
                                    }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.showingSummarySheet = false
                                    self.workout = nil
                                }
                            }
                        }
                    }
                })
            })
        })
    }
    
    /// Updates the run statistic
    private func updateStatistic(with locationData: LocationData? = nil) {
        if activeStatistics {
            
            // only count if we have some accuracy
            if locationAccuracy <= Constants.minHorizontalAccuracy {
                
                // only update if we have valid data
                if let newData = locationData ?? currentStatisticLocationData(refreshTimestamp: true) {
                    
                    // updating the show vars
                    let currentStatistic = runStatistics[currentRunStatisticIndex]
                    
                    // adding up the run time
                    if let firstDataEntry = runStatistics[currentRunStatisticIndex].locationData.first {
                        let startDate = firstDataEntry.timestamp
                        let timeSinceStart = secondsBetweenDates(from: startDate) / 60
                        runStatistics[currentRunStatisticIndex].runTime = timeSinceStart
                    }
                    
                    // adding up the distance if there is any data
                    if let lastData = currentStatistic.locationData.last {
                        
                        // calculate distance from location
                        let lastLatitude = lastData.latitude
                        let lastLongitude = lastData.longitude
                        let addedDistance = calculateDirectDistance(
                            from: Member(name: "lastLocation", latitude: lastLatitude, longitude: lastLongitude),
                            to: Member(name: "newLocation", latitude: newData.latitude, longitude: newData.longitude)
                        ) ?? 0.0
                        
                        runStatistics[currentRunStatisticIndex].runDistance += addedDistance
                    }
                    
                    // updating the top speed
                    if (newData.speed ?? 0.0) * 3.6 > currentStatistic.topSpeed {
                        runStatistics[currentRunStatisticIndex].topSpeed = (newData.speed ?? 0.0) * 3.6
                    }
                    
                    // updating the data
                    runStatistics[currentRunStatisticIndex].locationData.append(newData)
                }
            }
        }
    }
    
    private func currentStatisticLocationData(refreshTimestamp: Bool = false) -> LocationData? {
        if var locationData = latestStatisticLocationData {
            if refreshTimestamp {
                locationData.timestamp = Date.now
            }
            return locationData
        }
        
        guard let latitude = user.latitude, let longitude = user.longitude else {
            return nil
        }
        
        return LocationData(
            timestamp: Date.now,
            latitude: latitude,
            longitude: longitude,
            speed: user.speed ?? 0.0
        )
    }
    
    /// updating the member locations in the statistics
    private func updateMemberStatistics() {
        if activeStatistics {
            activeRun.members.forEach { member in
                if member.onlyWatching == false {
                    if let latitude = member.latitude, let longitude = user.longitude {
                        let newData = LocationData(timestamp: Date.now, latitude: latitude, longitude: longitude)
                        
                        if let statMemberIndex = runStatistics[currentRunStatisticIndex].crewStatistics.firstIndex(where: { $0.memberID == member.id }) {
                            runStatistics[currentRunStatisticIndex].crewStatistics[statMemberIndex].locationData.append(newData)
                        }
                        
                    }
                }
            }
        }
    }
    
    private func secondsBetweenDates(from pastDate: Date) -> Double {
        let calendar = Calendar.current
        let currentDate = Date.now
        
        let components = calendar.dateComponents([.second], from: pastDate, to: currentDate)
        return Double(components.second ?? 0)
    }
    
    /// delete all statistics
    func deleteStatistics() {
        runStatistics = []
        groupedRunStatistics = []
        saveRunStatistics()
        runEdits = []
        saveRunEdits(completeWipe: true)
    }
    
    // saving and loading statistics
    
    func createDateString(from date: Date?) -> String {
        if date != nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date!)
            return dateString
        } else {
            return ""
        }
    }
    
    // Helper method to get documents directory
    private func getDocumentsDirectory() throws -> URL {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            fatalError("Can't find documents directory.")
        }
    }
    
    /// Calculating all sessions in the for the year or month of the year. Returns totals plus distinct session days overall and per activity.
    func calculateSessions(for yearIndex: Int, month: Int? = nil) -> (total: Int, totalDays: Int, types: [WorkoutType: Int], typeDays: [WorkoutType: Int]) {
        var totalSessions = 0
        var workoutCounts: [WorkoutType: Int] = [:]
        var sessionDays = Set<Date>()
        var workoutSessionDays: [WorkoutType: Set<Date>] = [:]
        
        // Ensure year index is valid
        guard yearIndex >= 0 && yearIndex < groupedRunStatistics.count else {
            return (0, 0, [:], [:])
        }
        
        let yearData = groupedRunStatistics[yearIndex]
        let calendar = Calendar.current
        
        func addSessionDay(for run: RunStatistic) {
            guard let sessionDate = run.startDate ?? run.locationData.first?.timestamp else {
                return
            }
            
            let day = calendar.startOfDay(for: sessionDate)
            sessionDays.insert(day)
            
            if let type = run.workoutType {
                workoutSessionDays[type, default: []].insert(day)
            }
        }
        
        if let month = month {
            // Ensure month index is valid
            guard month >= 0 && month < yearData.count else {
                return (0, 0, [:], [:])
            }
            
            for run in yearData[month] {
                totalSessions += 1
                if let type = run.workoutType {
                    workoutCounts[type, default: 0] += 1
                }
                addSessionDay(for: run)
            }
            
        } else {
            // Iterate over all months
            for runs in yearData {
                for run in runs {
                    totalSessions += 1
                    if let type = run.workoutType {
                        workoutCounts[type, default: 0] += 1
                    }
                    addSessionDay(for: run)
                }
            }
        }
        
        let workoutDayCounts = workoutSessionDays.mapValues(\.count)
        return (totalSessions, sessionDays.count, workoutCounts, workoutDayCounts)
    }
    
    func getWorkoutsOfList() -> [String] {
        var workoutStrings: [String] = []
        for run in runStatistics {
            if let type = run.workoutType {
                let string = type.prettyString
                if !workoutStrings.contains(string) {
                    workoutStrings.append(string)
                }
            }
        }
        workoutStrings.sort()
        return workoutStrings
    }
    
    func calculateDistance(for yearIndex: Int, month: Int? = nil) -> (total: String, types: [WorkoutType: Double]) {
        var totalDistance = 0.0
        var workoutDistances: [WorkoutType: Double] = [:]

        if groupedRunStatistics.count > yearIndex {
            if month == nil {
                for runs in groupedRunStatistics[yearIndex] {
                    for run in runs {
                        if let type = run.workoutType {
                            totalDistance += run.runDistance
                            workoutDistances[type, default: 0] += run.runDistance
                        }
                    }
                }
            } else {
                for run in groupedRunStatistics[yearIndex][month!] {
                    if let type = run.workoutType {
                        totalDistance += run.runDistance
                        workoutDistances[type, default: 0] += run.runDistance
                    }
                }
            }
        }

        let totalString = totalDistance == 0 ? "" : makePrettyDistance(meters: totalDistance, system: measurementSystem)

        return (totalString, workoutDistances)
    }
    
    func calculateDownwindDistance(for yearIndex: Int, month: Int? = nil) -> (total: String, types: [WorkoutType: Double]) {
        var totalDistance = 0.0
        var workoutDistances: [WorkoutType: Double] = [:]

        if groupedRunStatistics.count > yearIndex {
            if month == nil {
                for runs in groupedRunStatistics[yearIndex] {
                    for run in runs {
                        if let type = run.workoutType, type.isDWSport {
                            totalDistance += run.runDistance
                            workoutDistances[type, default: 0] += run.runDistance
                        }
                    }
                }
            } else {
                for run in groupedRunStatistics[yearIndex][month!] {
                    if let type = run.workoutType, type.isDWSport {
                        totalDistance += run.runDistance
                        workoutDistances[type, default: 0] += run.runDistance
                    }
                }
            }
        }

        let totalString = totalDistance == 0 ? "" : makePrettyDistance(meters: totalDistance, system: measurementSystem)

        return (totalString, workoutDistances)
    }
    
    func calculateUpDownwindDistance(for yearIndex: Int, month: Int? = nil) -> (total: String, types: [WorkoutType: Double]) {
        var totalDistance = 0.0
        var workoutDistances: [WorkoutType: Double] = [:]

        if groupedRunStatistics.count > yearIndex {
            if month == nil {
                for runs in groupedRunStatistics[yearIndex] {
                    for run in runs {
                        if let type = run.workoutType, type.isUpDownwindSport {
                            totalDistance += run.runDistance
                            workoutDistances[type, default: 0] += run.runDistance
                        }
                    }
                }
            } else {
                for run in groupedRunStatistics[yearIndex][month!] {
                    if let type = run.workoutType, type.isUpDownwindSport {
                        totalDistance += run.runDistance
                        workoutDistances[type, default: 0] += run.runDistance
                    }
                }
            }
        }

        let totalString = totalDistance == 0 ? "" : makePrettyDistance(meters: totalDistance, system: measurementSystem)

        return (totalString, workoutDistances)
    }

    func calculateTimeOnWater(for yearIndex: Int, month: Int? = nil) -> (total: String, types: [WorkoutType: Double]) {
        var totalTime = 0.0
        var workoutTimes: [WorkoutType: Double] = [:]

        if groupedRunStatistics.count > yearIndex {
            if month == nil {
                for runs in groupedRunStatistics[yearIndex] {
                    for run in runs {
                        totalTime += run.runTime
                        if let type = run.workoutType {
                            workoutTimes[type, default: 0] += run.runTime
                        }
                    }
                }
            } else {
                for run in groupedRunStatistics[yearIndex][month!] {
                    totalTime += run.runTime
                    if let type = run.workoutType {
                        workoutTimes[type, default: 0] += run.runTime
                    }
                }
            }
        }

        let totalString = totalTime == 0 ? "" : makePrettyTime(timeInMinutes: totalTime)

        return (totalString, workoutTimes)
    }
    
    
    // File name of the statistics data
    private let fileName = "locationStatistics.data"
    private let editFileName = "runEdits.data"
    private let backupWorkoutDataFileName = "backupWorkout.data"
    private let importFileName = "importedRuns.data"
    
    
    /// Save runStatistics to disk
    func saveRunStatistics(array: [RunStatistic]? = nil) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(array ?? self.runStatistics)
                let url = try self.getDocumentsDirectory().appendingPathComponent(self.fileName)
                try data.write(to: url)
            } catch {
                print("Error saving runStatistics: \(error)")
            }
        }
    }
    
    private let saveQueue = DispatchQueue(label: "runEdits.save.queue")

    /// Save runEdits to disk with safety check.
    /// If more than 1 RunEdit would be lost, cancel and restore disk version.
    func saveRunEdits(completeWipe: Bool = false) {
        if completeWipe {
            do {
                let url = try self.getDocumentsDirectory().appendingPathComponent(self.editFileName)
                let newData = try JSONEncoder().encode(runEdits)
                try newData.write(to: url, options: .atomicWrite)
            } catch {
                print("Error removing all runEdits: \(error)")
            }
            
        } else {
            let newEdits = self.runEdits  // snapshot

            saveQueue.async {
                do {
                    // Load existing edits from disk
                    let url = try self.getDocumentsDirectory().appendingPathComponent(self.editFileName)
                    
                    var oldEdits: [RunEdit] = []
                    if let oldData = try? Data(contentsOf: url),
                       let decodedOld = try? JSONDecoder().decode([RunEdit].self, from: oldData) {
                        oldEdits = decodedOld
                    }

                    let oldCount = oldEdits.count
                    let newCount = newEdits.count

                    // Check shrinking
                    if oldCount > newCount {
                        let missing = oldCount - newCount

                        // If more than 1 item missing, cancel the save
                        if missing > 1 {
                            
                            self.logError("Prevented runEdits save: \(missing) edits would be lost. Restoring disk version.")

                            DispatchQueue.main.async {
                                self.runEdits = oldEdits  // restore the safe version
                            }
                            return
                        }
                    }

                    // All good → proceed with atomic write
                    let newData = try JSONEncoder().encode(newEdits)
                    try newData.write(to: url, options: .atomicWrite)

                } catch {
                    print("Error saving runEdits: \(error)")
                }
        }
        
        }
    }
    
    
    func deleteWorkout(id: UUID) {
        // delete backup if available
        if let backupIndex = backupWorkoutData.firstIndex(where: { $0.id == id }) {
            backupWorkoutData.remove(at: backupIndex)
            saveBackupWorkoutDataToDisk()
        }
        
        if HKHealthStore.isHealthDataAvailable() {
            // remove imported run if it is an imported one
            if let index = importedRuns.firstIndex(where: { $0.id == id }) {
                importedRuns.remove(at: index)
                saveImportedRunsToDisk()
                if let editIndex = self.runEdits.firstIndex(where: { $0.id == id }) {
                    runEdits.remove(at: editIndex)
                    saveRunEdits()
                }
                
                if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                    DispatchQueue.main.async {
                        self.runStatistics.remove(at: runIndex)
                        self.updateGroupedRunArray()
                    }
                }
                
            } else {
                let workoutPredicate = HKQuery.predicateForObject(with: id)
                
                // Create a query to fetch the workout
                let workoutQuery = HKSampleQuery(sampleType: .workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
                    guard error == nil else {
                        // Handle error
                        print("Error fetching workout: \(error!.localizedDescription)")
                        return
                    }
                    
                    if let workout = samples?.first as? HKWorkout {
                        
                        // remove workout
                        self.healthStore.delete(workout) { (success, error) in
                            if let error = error {
                                print("Error deleting workout: \(error.localizedDescription)")
                                return
                            }
                            
                            if success {
                                // also remove it from the arrays
                                if let editIndex = self.runEdits.firstIndex(where: { $0.id == id }) {
                                    DispatchQueue.main.async {
                                        self.runEdits.remove(at: editIndex)
                                        self.saveRunEdits()
                                    }
                                }
                                
                                if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                                    DispatchQueue.main.async {
                                        self.runStatistics.remove(at: runIndex)
                                        self.updateGroupedRunArray()
                                    }
                                }
                            }
                        }
                        
                    } else {
                        print("No workout found with the specified UUID. Saving the original array to disk")
                        // if can't find in health
                        if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                            DispatchQueue.main.async {
                                self.runStatistics.remove(at: runIndex)
                                self.updateGroupedRunArray()
                            }
                    }
                        // load old statistics from disk
                        var oldStatistics = self.getRunStatisticsFromDisk()
                        
                        // find the to deleted statistic
                        if let indexToRemove = oldStatistics.firstIndex(where: { $0.id == id }) {
                            oldStatistics.remove(at: indexToRemove)
                            self.saveRunStatistics(array: oldStatistics)
                        }
                    }
                }
                
                healthStore.execute(workoutQuery)
            }
        } else {
            // only remove it from the arrays
            if let editIndex = runEdits.firstIndex(where: { $0.id == id }) {
                DispatchQueue.main.async {
                    self.runEdits.remove(at: editIndex)
                    self.saveRunEdits()
                }
                
            }
            
            if let runIndex = runStatistics.firstIndex(where: { $0.id == id }) {
                DispatchQueue.main.async {
                    self.runStatistics.remove(at: runIndex)
                    
                    // load old statistics from disk
                    var oldStatistics = self.getRunStatisticsFromDisk()
                    
                    // find the to deleted statistic
                    if let indexToRemove = oldStatistics.firstIndex(where: { $0.id == id }) {
                        oldStatistics.remove(at: indexToRemove)
                        self.saveRunStatistics(array: oldStatistics)
                    }
                    
                    self.updateGroupedRunArray()
                }
            }
        }
    }
    
    private func getRunStatisticsFromDisk() -> [RunStatistic] {
        do {
            let url = try self.getDocumentsDirectory().appendingPathComponent(self.fileName)
            let data = try Data(contentsOf: url)
            let decodedStatistics = try JSONDecoder().decode([RunStatistic].self, from: data)
            return decodedStatistics
        } catch {
            print("Error loading runStatistics: \(error)")
            return []
        }
    }
    
    private func loadBackupWorkoutDataFromDisk() {
        do {
            let url = try self.getDocumentsDirectory().appendingPathComponent(self.backupWorkoutDataFileName)
            let data = try Data(contentsOf: url)
            let decodedStatistics = try JSONDecoder().decode([RunStatistic].self, from: data)
            backupWorkoutData = decodedStatistics
        } catch {
            print("Error loading runStatistics: \(error)")
        }
    }
    
    func saveBackupWorkoutDataToDisk() {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(self.backupWorkoutData)
                let url = try self.getDocumentsDirectory().appendingPathComponent(self.backupWorkoutDataFileName)
                try data.write(to: url)
            } catch {
                print("Error saving runStatistics: \(error)")
            }
        }
    }
    
    
    /// Load runStatistics from disk
    func loadRunStatistics() {
        loadingRunStatistics = true
        
        // getting the runStatistics (if no health or for older files)
        var decodedStatistics = getRunStatisticsFromDisk()
        // some cleaning up for old data
        for (index, statistic) in decodedStatistics.enumerated() {
            if statistic.startDate == nil {
                decodedStatistics[index].startDate = statistic.locationData.first?.timestamp
                decodedStatistics[index].endDate = statistic.locationData.last?.timestamp
            }
        }
        DispatchQueue.main.async {
            // Update UI on the main thread
            self.runStatistics = decodedStatistics
        }
        
        // getting the backup health from disk
        loadBackupWorkoutDataFromDisk()
        
        do {
            // getting the runEdits
            let editURL = try self.getDocumentsDirectory().appendingPathComponent(self.editFileName)
            let editData = try Data(contentsOf: editURL)
            let decodedEdits = try JSONDecoder().decode([RunEdit].self, from: editData)
            
            runEdits = decodedEdits
            
        } catch {
            logError("Error loading runEdits: \(error)")
        }
        
        
        DispatchQueue.global(qos: .background).async {
            
            self.loadWorkoutsFromHealthKit { workouts in
                
                // Update the statistic from health
                if HKHealthStore.isHealthDataAvailable() {
                    for workout in workouts {
                        // find runEdit, and use that one for anything it has and save it to runStatistics[runIndex]
                        var runEdit: RunEdit?
                        if let runEditIndex = self.runEdits.firstIndex(where: { $0.id == workout.uuid }) {
                            runEdit = self.runEdits[runEditIndex]
                        }
                        // check if there is a backup
                        let backup = self.backupWorkoutData.first(where: { $0.startDate == workout.startDate })
                        // get meta data
                        let metaData = self.getWorkoutMetadata(workout: workout, backup: backup)
                        // create the statistic
                        if let runIndex = self.runStatistics.firstIndex(where: { $0.id == workout.uuid }) {
                            DispatchQueue.main.async {
                                self.runStatistics[runIndex].runTime = runEdit?.newTotalTime ?? workout.duration / 60
                                self.runStatistics[runIndex].runDistance = runEdit?.newTotalDistance ?? metaData.totalDistance
                                self.runStatistics[runIndex].topSpeed = runEdit?.newTopSpeed ?? metaData.topSpeed
                                self.runStatistics[runIndex].averageSpeed = runEdit?.newAverageSpeed ?? metaData.averageSpeed
                                self.runStatistics[runIndex].kCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                                self.runStatistics[runIndex].tags = runEdit?.newTags ?? metaData.tags
                                self.runStatistics[runIndex].workoutType = runEdit?.newWorkoutType ?? metaData.workoutType
                                self.runStatistics[runIndex].startDate = runEdit?.startLocation?.timestamp ?? workout.startDate
                                self.runStatistics[runIndex].endDate = runEdit?.finishLocation?.timestamp ?? workout.endDate
                                self.runStatistics[runIndex].startLocation = metaData.startLocation
                                self.runStatistics[runIndex].locationString = runEdit?.locationString
                                self.runStatistics[runIndex].topSpeed1s = runEdit?.topSpeed1s
                                self.runStatistics[runIndex].topSpeed10s = runEdit?.topSpeed10s
                                self.runStatistics[runIndex].popUps = runEdit?.popUps
                                self.runStatistics[runIndex].percentageOnFoil = runEdit?.percentageOnFoil
                                self.runStatistics[runIndex].turnsCount = runEdit?.turnsCount
                                self.runStatistics[runIndex].angles = runEdit?.angles ?? []
                            }
                        } else {
                            var statistic = RunStatistic(id: workout.uuid, runName: "", crewStatistics: [], runTime: runEdit?.newTotalTime ?? workout.duration / 60, runDistance: runEdit?.newTotalDistance ?? metaData.totalDistance, topSpeed: runEdit?.newTopSpeed ?? metaData.topSpeed, averageSpeed: runEdit?.newAverageSpeed ?? metaData.averageSpeed, kCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0, locationData: [], tags: runEdit?.newTags ?? metaData.tags, workoutType: runEdit?.newWorkoutType ?? metaData.workoutType, startDate: runEdit?.startLocation?.timestamp ?? workout.startDate, endDate: runEdit?.finishLocation?.timestamp ?? workout.endDate, topSpeed1s: runEdit?.topSpeed1s ?? 0, topSpeed10s: runEdit?.topSpeed10s ?? 0, popUps: runEdit?.popUps ?? 0, percentageOnFoil: runEdit?.percentageOnFoil ?? 0, turnsCount: runEdit?.turnsCount ?? 0)
                            statistic.startLocation = metaData.startLocation
                            statistic.locationString = runEdit?.locationString
                            statistic.angles = runEdit?.angles ?? []
                            
                            DispatchQueue.main.async {
                                self.runStatistics.append(statistic)
                            }
                        }
                    }
                    
                    self.loadImportedRunsFromDisk()
                    
                    for run in self.importedRuns {
                        // overwriting the statistic if we find one at the same time as we are pretty sure we don't want both of them
                        
                        let matchingRuns = self.runStatistics.filter { self.doTimeRangesOverlap(start1: $0.startDate, end1: $0.endDate, start2: run.locations.first?.timestamp, end2: run.locations.last?.timestamp) }
                        DispatchQueue.main.async {
                            self.runStatistics.removeAll { statisticRun in
                                matchingRuns.contains(where: { $0.id == statisticRun.id })
                            }
                        }
                        // checking for run edit
                        var runEdit: RunEdit?
                        if let runEditIndex = self.runEdits.firstIndex(where: { $0.id == run.id }) {
                            runEdit = self.runEdits[runEditIndex]
                        }
                        
                        var newStatistic = RunStatistic(id: run.id, runName: "", crewStatistics: [], runTime: runEdit?.newTotalTime ?? run.runTime, runDistance: runEdit?.newTotalDistance ?? run.totalDistance, topSpeed: runEdit?.newTopSpeed ?? run.topSpeed, averageSpeed: runEdit?.newAverageSpeed ?? run.averageSpeed, kCalories: 0, locationData: run.locations, tags: runEdit?.newTags ?? run.tags, workoutType: runEdit?.newWorkoutType ?? run.workoutType ?? .surf, startDate: runEdit?.startLocation?.timestamp ?? run.startLocation?.timestamp ?? Date(), endDate: runEdit?.finishLocation?.timestamp ?? run.locations.last?.timestamp ?? Date(), topSpeed1s: runEdit?.topSpeed1s ?? 0, topSpeed10s: runEdit?.topSpeed10s ?? 0, popUps: runEdit?.popUps ?? 0, percentageOnFoil: runEdit?.percentageOnFoil ?? 0, turnsCount: runEdit?.turnsCount ?? 0)
                        newStatistic.startLocation = run.startLocation
                        newStatistic.locationString = runEdit?.locationString ?? run.locationString
                        newStatistic.angles = runEdit?.angles ?? []
                        
                        DispatchQueue.main.async {
                            self.runStatistics.append(newStatistic)
                        }
                    }
                    
                    let updatedTags = self.updateMetaData(statistics: self.runStatistics)
                    
                    // sort the array, find matching statistics update the grouped array
                    DispatchQueue.main.async {
                        self.tags = updatedTags
                        
                        self.saveTags()
                        
                        self.runStatistics.sort(by: { $0.startDate ?? $0.locationData.first?.timestamp ?? Date.distantPast > $1.startDate ?? $1.locationData.first?.timestamp ?? Date.distantPast})
                        
                        self.findMatchingStatisticsAndMerge()
                        
                        // Free user only show 5 runs
                        if !self.hasPurchasedPremium {
                            self.statisticsCount = self.runStatistics.count
                            if self.statisticsCount > 5 {
                                self.runStatistics = Array(self.runStatistics.prefix(5))
                            }
                        }
                        
                        self.updateGroupedRunArray()
                        
                        self.loadingRunStatistics = false
                        
                        self.updateLocationStrings()
                        
                    }
                }
            }
        }
    }
    
    private func doTimeRangesOverlap(start1: Date?, end1: Date?, start2: Date?, end2: Date?) -> Bool {
        guard let start1 = start1, let start2 = start2, let end1 = end1, let end2 = end2 else { return false }
        return start1 <= end2 && start2 <= end1
    }
    
    private func isWithinFiveMinutes(_ date1: Date?, _ date2: Date?) -> Bool {
        guard let date1 = date1, let date2 = date2 else { return false }
        return abs(date1.timeIntervalSince(date2)) <= 300 // 300 seconds = 5 minutes
    }
    
    private func findMatchingStatisticsAndMerge() {
        var idsToRemove = [UUID]()
        for i in 0..<runStatistics.count {
            for j in i+1..<runStatistics.count {
                let stat1 = runStatistics[i]
                let stat2 = runStatistics[j]
                
                if doTimeRangesOverlap(start1: stat1.startDate, end1: stat2.endDate, start2: stat2.startDate, end2: stat2.endDate) {
                    // Do your stuff here if both startDate and endDate are within ±5 minutes
                    idsToRemove.append(mergeStatistics(stat1Index: i, stat2Index: j))
                }
            }
        }
        
        runStatistics.removeAll { statistic in
            idsToRemove.contains(statistic.id)
        }
    }
    
    private func mergeStatistics(stat1Index: Int, stat2Index: Int) -> UUID {
        var originalIndex = stat1Index
        var extraIndex = stat2Index
        
        // fixing the naming if not correct
        if runStatistics[originalIndex].workoutType == .not7IIISurfingSport {
            extraIndex = stat1Index
            originalIndex = stat2Index
        }
        let originalStatistic = runStatistics[originalIndex]
        let extraStatistic = runStatistics[extraIndex]
        
        // attach the calories to the original stat
        if (originalStatistic.kCalories ?? 0) == 0 {
            if let newCalories = extraStatistic.kCalories {
                if newCalories != 0 {
                    runStatistics[originalIndex].kCalories = newCalories
                }
            }
        }
        
        // index to remove
        return extraStatistic.id
    }
    
    private func getWorkoutMetadata(workout: HKWorkout, backup: RunStatistic?) -> (tags: [String], workoutType: WorkoutType, averageSpeed: Double, topSpeed: Double, totalDistance: Double, startLocation: LocationData?) {
        let rawWorkoutType = workout.metadata?[Constants.customMetadataKeyWorkoutType] as? String ?? ""
        let tagsString = workout.metadata?[Constants.customMetadataKeyTags] as? String ?? ""
        let tags = tagsString.split(separator: " ").map { String($0) }
        
        let workoutType = WorkoutType(rawValue: rawWorkoutType) ?? .not7IIISurfingSport
        
        let topSpeed: Double
        if let maxSpeedQuantity = workout.metadata?[HKMetadataKeyMaximumSpeed] as? HKQuantity {
            // Assuming the unit is meters per second (m/s), convert it to kilometers per hour (km/h)
            topSpeed = maxSpeedQuantity.doubleValue(for: .meter().unitDivided(by: .second())) * 3.6
        } else {
            topSpeed = backup?.topSpeed ?? 0
        }
        
        let averageSpeed: Double
        if let averageSpeedQuantity = workout.metadata?[HKMetadataKeyAverageSpeed] as? HKQuantity {
            // Assuming the unit is meters per second (m/s), convert it to kilometers per hour (km/h)
            averageSpeed = averageSpeedQuantity.doubleValue(for: .meter().unitDivided(by: .second())) * 3.6
        } else {
            averageSpeed = backup?.averageSpeed ?? 0
        }
        
        
        let totalDistance: Double
        if let distanceQuantity = workout.metadata?[Constants.customTotalDistanceKey] as? HKQuantity {
            // Assuming the unit is meters per second (m/s), convert it to kilometers per hour (km/h)
            totalDistance = distanceQuantity.doubleValue(for: .meter())
        } else {
            totalDistance = backup?.runDistance ?? 0
        }
        
        let startCLLocation = workout.metadata?[Constants.customLocationKey] as? String ?? nil
        var startLocation: LocationData? = nil
        if let startCLLocation = startCLLocation {
            let components = startCLLocation.split(separator: ",")
            if components.count == 2,
               let latitude = Double(components[0].trimmingCharacters(in: .whitespaces)),
               let longitude = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                startLocation = LocationData(timestamp: Date(), latitude: latitude, longitude: longitude)
            }
        } else {
            startLocation = backup?.startLocation
        }
                
        return (tags: tags, workoutType: workoutType, averageSpeed: averageSpeed, topSpeed: topSpeed, totalDistance: totalDistance, startLocation: startLocation)
    }
    
    func updateGroupedRunArray() {
        let calendar = Calendar.current
        var grouped: [[[RunStatistic]]] = []
        
        for statistic in runStatistics {
            let components = calendar.dateComponents([.year, .month], from: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.distantPast)
            let year = components.year!
            let month = components.month!
            
            if grouped.isEmpty || calendar.component(.year, from: grouped.last!.last!.first!.startDate ?? Date.distantPast) != year {
                grouped.append([])
            }
            
            if grouped.last!.isEmpty || calendar.component(.month, from: grouped.last!.last!.first!.startDate ?? Date.distantPast) != month {
                grouped[grouped.count - 1].append([])
            }
            
            grouped[grouped.count - 1][grouped.last!.count - 1].append(statistic)
        }
        
        DispatchQueue.main.async {
            self.groupedRunStatistics = grouped
        }
    }

    func updateGroupedRunArraySync() {
        let calendar = Calendar.current
        var grouped: [[[RunStatistic]]] = []

        for statistic in runStatistics {
            let components = calendar.dateComponents([.year, .month], from: statistic.startDate ?? statistic.locationData.first?.timestamp ?? Date.distantPast)
            let year = components.year!
            let month = components.month!

            if grouped.isEmpty || calendar.component(.year, from: grouped.last!.last!.first!.startDate ?? Date.distantPast) != year {
                grouped.append([])
            }

            if grouped.last!.isEmpty || calendar.component(.month, from: grouped.last!.last!.first!.startDate ?? Date.distantPast) != month {
                grouped[grouped.count - 1].append([])
            }

            grouped[grouped.count - 1][grouped.last!.count - 1].append(statistic)
        }

        self.groupedRunStatistics = grouped
    }

    private func loadWorkoutsFromHealthKit(completion: @escaping ([HKWorkout]) -> Void) {
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .paddleSports),
            HKQuery.predicateForWorkouts(with: .sailing),
            HKQuery.predicateForWorkouts(with: .surfingSports)
        ])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKQuantityType.workoutType(),
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout] else {
                print("Error fetching workouts: \(String(describing: error))")
                completion([])
                return
            }
            completion(workouts)
        }
        
        healthStore.execute(query)
    }
    
    // TODO: fetch everything from importedRuns if the run is found there in this func
    func loadRouteAndHeartFromHealth(statistic: RunStatistic, withHeartRates: Bool = true, completion: @escaping (Bool) -> Void) {
        let id = statistic.id
        
        // skip everything if we have an imported run
        if let importedRun = self.importedRuns.first(where: { $0.id == id }) {
            if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
            // we only need to edit if we have a run edit
                if let runEdit = self.runEdits.first(where: { $0.id == id }) {
                    // filtering out the deleted locations
                    if let deletedLocations = runEdit.deletedLocations {
                        let newLocationData = importedRun.locations.filter { !deletedLocations.contains($0)}
                        DispatchQueue.main.async {
                            self.runStatistics[runIndex].locationData = newLocationData
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.runStatistics[runIndex].locationData = importedRun.locations
                    }
                }
                
                // heart rate
                if importedRun.heartRates.count > 0 && withHeartRates {
                    self.runStatistics[runIndex].averageHeartRate = importedRun.averageHeartRate
                }
                completion(true)
            }
        } else {
            
            let dispatchGroup = DispatchGroup()
            
            // only do this part when we have health
            if HKHealthStore.isHealthDataAvailable() {
                
                // load the route and average heart rate
                self.loadWorkoutRouteHeartFromHealth(id: id, loadHeartRates: withHeartRates) { route, averageHeartRate in
                    if let route = route {
                        self.locationDataFromWorkoutRoute(route: route) { locationData in
                            if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                                var locationData = locationData
                                // find backup - this is done by comparing start date, but actually would make more sense to use id (?)
                                if let backupIndex = self.backupWorkoutData.firstIndex(where: { $0.startDate == statistic.startDate }) {
                                    if locationData.isEmpty {
                                        locationData = self.backupWorkoutData[backupIndex].locationData
                                    } else {
                                        self.backupWorkoutData.remove(at: backupIndex)
                                        self.saveBackupWorkoutDataToDisk()
                                    }
                                }
                                
                                // we only need to edit if we have a run edit
                                if let runEdit = self.runEdits.first(where: { $0.id == id }) {
                                    // filtering out the deleted locations
                                    if let deletedLocations = runEdit.deletedLocations {
                                        let newLocationData = locationData.filter { !deletedLocations.contains($0)}
                                        dispatchGroup.enter()
                                        DispatchQueue.main.async {
                                            self.runStatistics[runIndex].locationData = newLocationData
                                            dispatchGroup.leave()
                                        }
                                    } else {
                                        dispatchGroup.enter()
                                        DispatchQueue.main.async {
                                            self.runStatistics[runIndex].locationData = locationData
                                            dispatchGroup.leave()
                                        }
                                    }
                                } else {
                                    dispatchGroup.enter()
                                    DispatchQueue.main.async {
                                        self.runStatistics[runIndex].locationData = locationData
                                        dispatchGroup.leave()
                                    }
                                }
                            } else {
                                // we should never have to do that
                                let run = RunStatistic(id: id, runName: "", crewStatistics: [], runTime: 0.0, runDistance: 0.0, topSpeed: 0.0, locationData: locationData)
                                dispatchGroup.enter()
                                DispatchQueue.main.async {
                                    self.runStatistics.append(run)
                                    dispatchGroup.leave()
                                }
                            }
                            
                            if let averageHeartRate = averageHeartRate {
                                if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                                    dispatchGroup.enter()
                                    DispatchQueue.main.async {
                                        self.runStatistics[runIndex].averageHeartRate = averageHeartRate
                                        dispatchGroup.leave()
                                    }
                                }
                            }
                            
                            dispatchGroup.notify(queue: .main) {
                                completion(true)
                            }
                        }
                        
                    } else {
                        // If we don't have any route data, not even an empty one we try to find the backup. Very hacky
                        
                        var locationData = [LocationData]()
                        if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {

                            // find backup - this is done by comparing start date, but actually would make more sense to use id (?)
                            if let backupIndex = self.backupWorkoutData.firstIndex(where: { $0.startDate == statistic.startDate }) {
                                locationData = self.backupWorkoutData[backupIndex].locationData
                                
                            }
                            
                            // we only need to edit if we have a run edit
                            if let runEdit = self.runEdits.first(where: { $0.id == id }) {
                                // filtering out the deleted locations
                                if let deletedLocations = runEdit.deletedLocations {
                                    let newLocationData = locationData.filter { !deletedLocations.contains($0)}
                                    dispatchGroup.enter()
                                    DispatchQueue.main.async {
                                        self.runStatistics[runIndex].locationData = newLocationData
                                        dispatchGroup.leave()
                                    }
                                } else {
                                    dispatchGroup.enter()
                                    DispatchQueue.main.async {
                                        self.runStatistics[runIndex].locationData = locationData
                                        dispatchGroup.leave()
                                    }
                                }
                            } else {
                                dispatchGroup.enter()
                                DispatchQueue.main.async {
                                    self.runStatistics[runIndex].locationData = locationData
                                    dispatchGroup.leave()
                                }
                            }
                        } else {
                            // we should never have to do that
                            let run = RunStatistic(id: id, runName: "", crewStatistics: [], runTime: 0.0, runDistance: 0.0, topSpeed: 0.0, locationData: locationData)
                            dispatchGroup.enter()
                            DispatchQueue.main.async {
                                self.runStatistics.append(run)
                                dispatchGroup.leave()
                            }
                        }
                        
                        if let averageHeartRate = averageHeartRate {
                            if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                                dispatchGroup.enter()
                                DispatchQueue.main.async {
                                    self.runStatistics[runIndex].averageHeartRate = averageHeartRate
                                    dispatchGroup.leave()
                                }
                            }
                        }
                        
                        dispatchGroup.notify(queue: .main) {
                            completion(true)
                        }
                    }
                }
            } else {
                // when we don't save to health we need this process
                if let runEdit = runEdits.first(where: { $0.id == id }) {
                    if let deletedLocations = runEdit.deletedLocations {
                        if let runIndex = runStatistics.firstIndex(where: { $0.id == id }) {
                            let locationData = runStatistics[runIndex].locationData
                            let newLocationData = locationData.filter { !deletedLocations.contains($0)}
                            dispatchGroup.enter()
                            DispatchQueue.main.async {
                                self.runStatistics[runIndex].locationData = newLocationData
                                dispatchGroup.leave()
                            }
                        }
                    } else {
                        print("no deleted locations found")
                    }
                }
                dispatchGroup.notify(queue: .main) {
                    completion(false)
                }
            }
        }
    }
    
    private func loadWorkoutRouteFromID(id: UUID, completion: @escaping (HKWorkoutRoute?) -> Void) {
        // Create a predicate to fetch the workout with the given UUID
        let workoutPredicate = HKQuery.predicateForObject(with: id)
        
        // Create a query to fetch the workout
        let workoutQuery = HKSampleQuery(sampleType: .workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
            guard error == nil else {
                // Handle error
                print("Error fetching workout: \(error!.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let workout = samples?.first as? HKWorkout else {
                print("No workout found with the specified UUID.")
                completion(nil)
                return
            }
            
            // Once the workout is fetched, load its associated route and heart rates
            self.loadWorkoutRoute(workout: workout) { route in
                
                completion(route)
            }
        }
        
        healthStore.execute(workoutQuery)
    }
    
    
    private func loadWorkoutRouteHeartFromHealth(id: UUID, loadHeartRates: Bool = true, completion: @escaping (HKWorkoutRoute?, Double?) -> Void) {
        // Create a predicate to fetch the workout with the given UUID
        let workoutPredicate = HKQuery.predicateForObject(with: id)
        
        // Create a query to fetch the workout
        let workoutQuery = HKSampleQuery(sampleType: .workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
            guard error == nil else {
                // Handle error
                print("Error fetching workout: \(error!.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            guard let workout = samples?.first as? HKWorkout else {
                print("No workout found with the specified UUID.")
                completion(nil, nil)
                return
            }
            
            // Once the workout is fetched, load its associated route and heart rates
            self.loadWorkoutRoute(workout: workout) { route in
                
                if loadHeartRates {
                    self.getAVGHeartRate(for: workout) { averageHeartRate in
                        completion(route, averageHeartRate)
                    }
                } else {
                    completion(route, nil)
                }
                
            }
        }
        
        healthStore.execute(workoutQuery)
    }
    
    private func loadWorkoutRoute(workout: HKWorkout, completion: @escaping (HKWorkoutRoute?) -> Void) {
        let runningObjectQuery = HKQuery.predicateForObjects(from: workout)
        
        let routeQuery = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(), predicate: runningObjectQuery, anchor: nil, limit: HKObjectQueryNoLimit) { (query, samples, deletedObjects, anchor, error) in
            
            guard error == nil else {
                // Handle any errors here.
                fatalError("The initial query failed.")
            }
            
            // Process the initial route data here.
            guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
                completion(nil)
                return
            }
            completion(route)
            
        }
        healthStore.execute(routeQuery)
    }
    
    private func getAVGHeartRate(for workout: HKWorkout, completion: @escaping (Double?) -> Void) {
        let healthStore = HKHealthStore()
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }
        
        let startDate = workout.startDate
        let endDate = workout.endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { query, statistics, error in
            DispatchQueue.main.async {
                guard let statistics = statistics, error == nil else {
                    print("Error for heart rate: \(error!.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let averageQuantity = statistics.averageQuantity() {
                    let averageBPM = averageQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    completion(averageBPM)
                } else {
                    completion(nil)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHeartRatesOverTime(statisticID: UUID? = nil, startTime: Date?, endTime: Date?, completion: @escaping ([Date: (Double, Double)]?, Error?) -> Void) {
        if statisticID != nil {
            if let importedRun = importedRuns.first(where: { $0.id == statisticID }) {
                if importedRun.heartRates.count > 0 {
                    // Create comparable heart rates data
                    var heartRateData: [Date: (Double, Double)] = [:]

                    // Heart rates must be sorted
                    let sortedHeartRates = importedRun.heartRates
                        .sorted { $0.date < $1.date }

                    for heartRate in sortedHeartRates {
                        let second = floor(heartRate.date.timeIntervalSince1970)
                        let binDate = Date(timeIntervalSince1970: second)

                        if let existing = heartRateData[binDate] {
                            heartRateData[binDate] = (
                                min(existing.0, heartRate.heartRate),
                                max(existing.1, heartRate.heartRate)
                            )
                        } else {
                            heartRateData[binDate] = (
                                heartRate.heartRate,
                                heartRate.heartRate
                            )
                        }
                    }
                    
                    completion(heartRateData, nil)
                    return
                }
            }
        }
        
        guard let startTime = startTime, let endTime = endTime else {
            completion(nil, NSError(domain: "com.7iiitracker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Heart rate type not available"]))
            return
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, NSError(domain: "com.7iiitracker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Heart rate type not available"]))
            return
        }
        
        // Calculate the interval based on the startTime, endTime, and desired number of samples
        let interval = DateInterval(start: startTime, end: endTime)
        let intervalDuration = interval.duration
        let samplesCount = 80
        let timeInterval = max(Int(intervalDuration / Double(samplesCount)), 1)
        
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime)
        
        // Define the query to fetch heart rate statistics collection
        let query = HKStatisticsCollectionQuery(quantityType: heartRateType,
                                                quantitySamplePredicate: predicate,
                                                options: [.discreteMin, .discreteMax],
                                                anchorDate: startTime,
                                                intervalComponents: DateComponents(second: Int(timeInterval)))
        
        // Handle the results from the query
        query.initialResultsHandler = { query, statisticsCollection, error in
            guard let statisticsCollection = statisticsCollection, error == nil else {
                completion(nil, error)
                return
            }
            
            var heartRateData: [Date: (Double, Double)] = [:]
            
            // Enumerate through the statistics collection to populate heartRateData
            statisticsCollection.enumerateStatistics(from: startTime, to: endTime) { statistics, _ in
                var minHeartRate: Double = 0
                var maxHeartRate: Double = 0
                
                if let minValue = statistics.minimumQuantity() {
                    minHeartRate = minValue.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                }
                
                if let maxValue = statistics.maximumQuantity() {
                    maxHeartRate = maxValue.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                }
                if minHeartRate != 0.0 && maxHeartRate != 0.0 {
                    heartRateData[statistics.startDate] = (minHeartRate, maxHeartRate)
                }
            }
            completion(heartRateData, nil)
        }
        
        // Execute the query
        healthStore.execute(query)
    }
    
    
    private func locationDataFromWorkoutRoute(route: HKWorkoutRoute, completion: @escaping ([LocationData]) -> Void) {
        var allLocations = [LocationData]()
        
        let query = HKWorkoutRouteQuery(route: route) { (query, locationsOrNil, done, errorOrNil) in
            
            // This block may be called multiple times.
            
            if let error = errorOrNil {
                // Handle any errors here.
                self.logError("Error, no locations found: \(error) - in locationDataFromWorkoutRoute")
                return completion(allLocations)
            }
            
            guard let locations = locationsOrNil else {
                self.logError("*** Invalid State: This can only fail if there was an error.  - in locationDataFromWorkoutRoute ***")
                return completion(allLocations)
            }
            
            // Do something with this batch of location data.
            for location in locations {
                let locationData = LocationData(
                    timestamp: location.timestamp,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude.isFinite ? location.altitude : nil,
                    speed: location.speed,
                    verticalAccuracy: location.verticalAccuracy >= 0 && location.verticalAccuracy.isFinite ? location.verticalAccuracy : nil
                )
                allLocations.append(locationData)
            }
            
            if done {
                // The query returned all the location data associated with the route.
                // Do something with the complete data set.
                completion(allLocations)
            }
            
            // You can stop the query by calling:
            // store.stop(query)
            
        }
        healthStore.execute(query)
    }
    
    /// save location string to run edits
    func saveLocationString(string: String, statisticsID: UUID, withSaving: Bool = true) {
        if let editIndex = runEdits.firstIndex(where: { $0.id == statisticsID }) {
            runEdits[editIndex].locationString = string
        } else {
            let runEdit = RunEdit(id: statisticsID, locationString: string)
            runEdits.append(runEdit)
        }
        if withSaving {
            saveRunEdits()
        }
    }
    
    /// save top speeds to run edits
    func saveTopSpeeds(speed1s: Double?, speed10s: Double?, statisticsID: UUID) {
        if speed1s == nil || speed10s == nil { return }
        if let editIndex = runEdits.firstIndex(where: { $0.id == statisticsID }) {
            runEdits[editIndex].topSpeed1s = speed1s
            runEdits[editIndex].topSpeed10s = speed10s
        } else {
            let runEdit = RunEdit(id: statisticsID, topSpeed10s: speed10s, topSpeed1s: speed1s)
            runEdits.append(runEdit)
        }
        saveRunEdits()
    }
    
    /// save on foil stats to run edits
    func saveOnFoilStats(popUps: Int, percentageOnFoil: Double, turns: Int, longestDistanceOnFoil: Double, statisticsID: UUID, waves: [[LocationData]]) {
        if let editIndex = runEdits.firstIndex(where: { $0.id == statisticsID }) {
            runEdits[editIndex].popUps = popUps
            runEdits[editIndex].percentageOnFoil = percentageOnFoil
            runEdits[editIndex].turnsCount = turns
            runEdits[editIndex].longestDistanceOnFoil = longestDistanceOnFoil
            runEdits[editIndex].waves = waves
        } else {
            let runEdit = RunEdit(id: statisticsID, popUps: popUps, percentageOnFoil: percentageOnFoil, turnsCount: turns, longestDistanceOnFoil: longestDistanceOnFoil, waves: waves)
            runEdits.append(runEdit)
        }
        saveRunEdits()
    }
    
    
    /// save statistic to disk with new tags
    func saveStatisticWithNewTags(tags: [String], type: WorkoutType, saveType: Bool = false, statisticsData: RunStatistic, locationName: String = "") {
        if let editIndex = runEdits.firstIndex(where: { $0.id == statisticsData.id }) {
            runEdits[editIndex].newTags = tags
            if saveType {
                runEdits[editIndex].newWorkoutType = type
                runEdits[editIndex].locationString = locationName
            }
        } else {
            var runEdit = RunEdit(id: statisticsData.id, newTags: tags)
            if saveType {
                runEdit.newWorkoutType = type
                runEdit.locationString = locationName
            }
            runEdits.append(runEdit)
        }
        saveRunEdits()
        
        if let index = runStatistics.firstIndex(where: { $0.id == statisticsData.id }) {
            runStatistics[index].tags = tags
            if saveType {
                runStatistics[index].workoutType = type
                runStatistics[index].locationString = locationName
            }
        }
        
        updateGroupedRunArray()
        
        // adding tags to tags
        for tag in tags {
            if !self.tags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                self.tags.append(tag)
            }
        }
        self.tags = self.tags.sorted()

        saveTags()
        
        if saveType && !locationName.isEmpty {
            updateAndSortLocationStrings(location: locationName)
        }
    }
    
    /// save statistic to disk with new angles
    func saveStatisticAngles(statisticsData: RunStatistic) {
        let angles = statisticsData.angles
        if let editIndex = runEdits.firstIndex(where: { $0.id == statisticsData.id }) {
            runEdits[editIndex].angles = angles
        } else {
            let runEdit = RunEdit(id: statisticsData.id, angles: angles)
            runEdits.append(runEdit)
        }
        saveRunEdits()
        
        if let index = runStatistics.firstIndex(where: { $0.id == statisticsData.id }) {
            runStatistics[index].angles = angles
        }
        
        updateGroupedRunArray()
    }
    
    func createLocationNames(statisticsData: RunStatistic, completion: @escaping (String) -> Void) {
        var locationName = "Unknown Location"
        
        func processEndLocation() {
            if let lastDataPoint = statisticsData.locationData.last {
                GeocodingManager.shared.getNameOfLocation(location: lastDataPoint) { endName in
                    if let endName = endName, !locationName.contains("→"), locationName != endName {
                        locationName = locationName.isEmpty || locationName == "Unknown Location" ? endName : "\(locationName) → \(endName)"
                    }
                    completion(locationName)
                }
            } else {
                completion(locationName)
            }
        }
        
        if let firstDataPoint = statisticsData.locationData.first {
            GeocodingManager.shared.getNameOfLocation(location: firstDataPoint) { startName in
                if let startName = startName {
                    locationName = startName
                }
                processEndLocation()
            }
        } else if let startLocation = statisticsData.startLocation {
            GeocodingManager.shared.getNameOfLocation(location: startLocation) { startName in
                if let startName = startName {
                    locationName = startName
                }
                completion(locationName)
            }
        } else {
            completion(locationName)
        }
    }
    
    func saveEditedRoute(newStatistic: RunStatistic, updatingExternal: Bool = false) {
        
        if newStatistic.locationData.isEmpty {
            return
        }
        
        // we have to do this because health sometimes had no speed. should be fixed now.
        if newStatistic.locationData.randomElement()?.speed == -1.0 {
            var newStatistic = newStatistic
            newStatistic.locationData = newStatistic.locationData.map { location in
                var updatedLocation = location
                updatedLocation.speed = -1.0
                return updatedLocation
            }
        }
        
        if let index = runStatistics.firstIndex(where: { $0.id == newStatistic.id }) {
            // snapshot the run for later comparison
            let oldRoute = runStatistics[index].locationData
            
            if !updatingExternal {
                guard oldRoute != newStatistic.locationData else {
                    return
                }
            }
            
            // update the locationData of the run
            runStatistics[index].locationData = newStatistic.locationData
            
            // find what changed in the route
            var newRunEdit = RunEdit(id: newStatistic.id)
            
            // don't forget the tags! And somehow we also need to save the activity otherwise we will lose it
            newRunEdit.newTags = newStatistic.tags
            newRunEdit.newWorkoutType = newStatistic.workoutType
            
            // update start if changed
            if oldRoute.first! != newStatistic.locationData.first! {
                newRunEdit.startLocation = newStatistic.locationData.first!
                runStatistics[index].startDate = newRunEdit.startLocation?.timestamp
                
                // updating location string
                createLocationNames(statisticsData: newStatistic) { location in
                        self.saveLocationString(string: location, statisticsID: newStatistic.id)
                        self.runStatistics[index].locationString = location
                }
            }
            
            // update finish if changed
            if oldRoute.last! != newStatistic.locationData.last! {
                newRunEdit.finishLocation = newStatistic.locationData.last!
                runStatistics[index].endDate = newRunEdit.finishLocation?.timestamp
                
                // updating location string
                createLocationNames(statisticsData: newStatistic) { location in
                        self.saveLocationString(string: location, statisticsID: newStatistic.id)
                        self.runStatistics[index].locationString = location
                }
            }
            
            // update run time, speeds etc.
            runStatistics[index].runTime = runStatistics[index].endDate!.timeIntervalSince(runStatistics[index].startDate!) / 60
            newRunEdit.newTotalTime = runStatistics[index].runTime
            
            let newDistanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newStatistic.locationData)
            
            runStatistics[index].runDistance = newDistanceAndSpeed.totalDistance
            newRunEdit.newTotalDistance = newDistanceAndSpeed.totalDistance
            
            runStatistics[index].topSpeed = newDistanceAndSpeed.topSpeed
            newRunEdit.newTopSpeed = newDistanceAndSpeed.topSpeed
            
            runStatistics[index].averageSpeed = (newDistanceAndSpeed.totalDistance / 1000) / (runStatistics[index].runTime / 60)
            newRunEdit.newAverageSpeed = runStatistics[index].averageSpeed
            
            // updating 1 s and 10 s top speed
            let newTopSpeeds = calculateTopSpeeds(from: newStatistic.locationData)
            runStatistics[index].topSpeed1s = newTopSpeeds.topSpeed1Sec
            runStatistics[index].topSpeed10s = newTopSpeeds.topSpeed10Sec
            newRunEdit.topSpeed1s = newTopSpeeds.topSpeed1Sec
            newRunEdit.topSpeed10s = newTopSpeeds.topSpeed10Sec
            
            // updating falls and % on foil and turns
            if let workoutType = newStatistic.workoutType {
                var foilStats: (popUps: Int, timeOnFoilPercentage: Double, turns: Int, longestDistanceOnFoil: Double, waves: [[LocationData]]) = (0, 0, 0, 0, [[]])
                    if workoutType.calculateFoilingStats {
                        foilStats = calculateFoilingStats(from: newStatistic.locationData, thresholdSpeedKmh: workoutType.thresholdSpeedKmhSlowSpeedWithDefault, countTurns: workoutType.countTurns, returnWaves: workoutType.returnWaves)
                    }
                if foilStats != (popUps: 0, timeOnFoilPercentage: 0, turns: 0, longestDistanceOnFoil: 0, waves: [[]]) {
                    
                    runStatistics[index].popUps = foilStats.popUps
                    runStatistics[index].percentageOnFoil = foilStats.timeOnFoilPercentage
                    runStatistics[index].turnsCount = foilStats.turns
                    runStatistics[index].longestDistanceOnFoil = foilStats.longestDistanceOnFoil
                    runStatistics[index].waves = foilStats.waves
                    
                    newRunEdit.popUps = foilStats.popUps
                    newRunEdit.percentageOnFoil = foilStats.timeOnFoilPercentage
                    newRunEdit.turnsCount = foilStats.turns
                    newRunEdit.longestDistanceOnFoil = foilStats.longestDistanceOnFoil
                    newRunEdit.waves = foilStats.waves
                }
            }
            
            // now update the grouped array
            updateGroupedRunArray()
            
            func createEdits(locationData: [LocationData]) {
                let deletedLocations = self.findMissingLocationData(original: locationData, new: newStatistic.locationData)
                newRunEdit.deletedLocations = deletedLocations
                
                // save newRunEdit to the runEdit array if or replace if it exists.
                if let index = self.runEdits.firstIndex(where: { $0.id == newRunEdit.id }) {
                    self.runEdits[index] = newRunEdit
                } else {
                    self.runEdits.append(newRunEdit)
                }
                self.saveRunEdits()
            }
            
            // if we are working with an imported run
            if let index = importedRuns.firstIndex(where: { $0.id == newStatistic.id }) {
                let route = importedRuns[index].locations
                createEdits(locationData: route)
                
            } else {
                // if we don't have health kit available we have to go another way of saving the edit
                if HKHealthStore.isHealthDataAvailable() {
                    
                    // find locations missing in the newStatistic, in relation to the original locations
                    loadWorkoutRouteFromID(id: newStatistic.id) { route in
                        
                        if let route = route {
                            self.locationDataFromWorkoutRoute(route: route) { locationData in
                                createEdits(locationData: locationData)
                            }
                            // check if we find a backup
                        } else if let backupLocationData = self.backupWorkoutData.first(where: { $0.startDate == self.runStatistics[index].startDate })?.locationData {
                            createEdits(locationData: backupLocationData)
                        }
                    }
                    
                } else {
                    // find difference of oldRoute and new newStatistic.locationData when we don't have health
                    let deletedLocations = findMissingLocationData(original: oldRoute, new: newStatistic.locationData)
                    newRunEdit.deletedLocations = deletedLocations
                    
                    // save newRunEdit to the runEdit array if or replace if it exists.
                    if let index = runEdits.firstIndex(where: { $0.id == newRunEdit.id }) {
                        runEdits[index] = newRunEdit
                    } else {
                        runEdits.append(newRunEdit)
                    }
                    saveRunEdits()
                }
            }
        }
    }
    
    /// find missing location strings and add them
    private func updateLocationStrings() {
        var changedLocationStrings = false
        
        updateLocationStringsList()
        
        print("running location strings update")
        
        for statistic in runStatistics.sorted(by: { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }) {
            if statistic.locationString == nil || statistic.locationString == "" {
                
                loadWorkoutRouteEndpoints(id: statistic.id) { endpoints in
                    
                    if endpoints != nil || statistic.startLocation != nil {
                        let locationData = endpoints != nil ? [endpoints!.0, endpoints!.1] : []
                        let fakeRunStatistic = RunStatistic(id: statistic.id, locationData: locationData, startLocation: statistic.startLocation)
                        
                        if !changedLocationStrings {
                            changedLocationStrings = true
                        }
                        
                        if let index = self.runStatistics.firstIndex(where: { $0.id == statistic.id }) {
//                            dispatchGroup.enter()
                            self.createLocationNames(statisticsData: fakeRunStatistic) { location in
                                DispatchQueue.main.async {
                                    // saving to run edits without saving them to disk (will do that only once and later)
                                    self.saveLocationString(string: location, statisticsID: statistic.id, withSaving: true)
                                    self.runStatistics[index].locationString = location
                                    // updating the locationStrings
                                    self.updateAndSortLocationStrings(location: location)
                                }
                                // let dateString = statistic.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "unknown"

                                // print("updating location string of: \(location), date: \(dateString)")
//                                dispatchGroup.leave()
                                self.updateGroupedRunArray()
                                
                            }
                        }
                        
                    } else {
                        // print("Could not load route endpoints nor startLocation found for run")
                    }
                }
            }
        }
    }
    
    func updateAndSortLocationStrings(location: String) {
        if !locationStrings.contains(location) {
            locationStrings.append(location)
        }
        locationStrings.sort()
    }
    
    private func loadWorkoutRouteEndpoints(id: UUID, completion: @escaping ((LocationData, LocationData)?) -> Void) {
        // Only proceed if health data is available
        guard HKHealthStore.isHealthDataAvailable() else {
            // when we don't save to health we need this process
            if let runEdit = runEdits.first(where: { $0.id == id }) {
                if let deletedLocations = runEdit.deletedLocations {
                    if let runIndex = runStatistics.firstIndex(where: { $0.id == id }) {
                        let locationData = runStatistics[runIndex].locationData
                        let newLocationData = locationData.filter { !deletedLocations.contains($0)}
                        if newLocationData.count >= 2 {
                            completion((newLocationData.first!, newLocationData.last!))
                        }
                    }
                }
            }
            completion(nil)
            return
        }
        
        // Load the workout route
        loadWorkoutRouteHeartFromHealth(id: id, loadHeartRates: false) { route, _ in
            guard let route = route else {
                completion(nil)
                return
            }
            
            // Convert route to location data
            self.locationDataFromWorkoutRoute(route: route) { locationData in
                var locationData = locationData
                // find backup
                if let backupIndex = self.backupWorkoutData.firstIndex(where: { $0.id == id }) {
                    if locationData.isEmpty {
                        locationData = self.backupWorkoutData[backupIndex].locationData
                    }
                }
                
                // Check if we have enough location points
                guard locationData.count >= 2 else {
                    completion(nil)
                    return
                }
                
                let firstLocation = locationData[0]
                let lastLocation = locationData[locationData.count - 1]
                
                DispatchQueue.main.async {
                    completion((firstLocation, lastLocation))
                }
            }
        }
    }
    
    
    private func updateLocationStringsList() {
        DispatchQueue.main.async {
            for statistic in self.runStatistics {
            if let string = statistic.locationString, string != "" {
                if !self.locationStrings.contains(string) {
                        self.locationStrings.append(string)
                    }
                }
            }
            
            self.locationStrings.sort()
        }
    }
    
    
    /// returns missing locations
    private func findMissingLocationData(original: [LocationData], new: [LocationData]) -> [LocationData] {
        let missingData = original.filter { !new.contains($0) }
        return missingData
    }
    
    
    /// updates the metadata of the run statistics
    private func updateMetaData(statistics: [RunStatistic]) -> [String] {
        var tags = [String]()
        
        for statistic in statistics {
            if statistic.tags != nil {
                for tag in statistic.tags! {
                    if !tags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                        tags.append(tag)
                    }
                }
            }
        }
        
        return tags.sorted()
    }
    
    /// filter the grouped statistics array
    func filterGroupedStatistics(tags: [String], location: String, workout: String, onlyAngles: Bool = false) -> [[[RunStatistic]]] {
        if tags.isEmpty && location.isEmpty && workout.isEmpty && onlyAngles == false {
            return groupedRunStatistics
        } else {
            let filteredGroupedStatistics = groupedRunStatistics.map { group in
                group.map { subGroup in
                    subGroup.filter { statistic in
                        // Filter by tags
                        let tagMatches = tags.isEmpty || tags.allSatisfy { tag in
                            if let statisticTags = statistic.tags {
                                let tagString = statisticTags.joined(separator: " ").lowercased()
                                return tagString.contains(tag.lowercased())
                            } else {
                                return false
                            }
                        }
                        
                        // Filter by location & workout
                        let locationMatches = location.isEmpty || statistic.locationString == location
                        let workoutMatches = workout.isEmpty || (statistic.workoutType?.prettyString ?? "") == workout
                        
                        // Filter by saved angles
                        let angleMatches = !onlyAngles || statistic.angles?.count ?? 0 > 0
                        
                        return tagMatches && locationMatches && workoutMatches && angleMatches
                    }
                }
            }
            return filteredGroupedStatistics
        }
    }
    
    /// encoding and printing location data
    func encodeAndPrintRunStatistics(statistics: RunStatistic) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(statistics.locationData)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString)
                } else {
                    print("Error: Unable to convert JSON data to string")
                }
            } catch {
                print("Error saving runStatistics: \(error)")
            }
        }
    }
    
    
    /// print runStatistics
    func printRunStatistics(statistics: RunStatistic) -> String {
        var string = "["
        var secondsToAddToDate = 0
        let secondsAgoStarted = 24 * 60 * 60 * 2
        
        for location in statistics.locationData {
            let locationString = "LocationData(timestamp: \(Date.now.addingTimeInterval(TimeInterval(secondsAgoStarted - secondsToAddToDate))), latitude: \(location.latitude), longitude: \(location.longitude), speed: \(location.speed ?? 0.0)), "
            string.append(locationString)
            
            secondsToAddToDate += 1
        }
        string.append("]")
        return string
    }
    
    /// create rounds from locationData for Statistics
    func createRounds(for locations: [LocationData]) -> [(String, String, String)] {
        // safety measure
        if !locations.isEmpty {
            var accumulatedDistance = 0.0
            var numberOfKm = 0
            var lastKmDate = locations.first?.timestamp ?? Date.now
            var roundsArray = [(String, String)]()
            var timesArray = [Double]()
            let roundLength = 1.0
            
            for index in 1..<locations.count {
                // Update distance
                let lastLatitude = locations[index-1].latitude
                let lastLongitude = locations[index-1].longitude
                let presentLatitude = locations[index].latitude
                let presentLongitude = locations[index].longitude
                let addedDistance = (calculateDirectDistance(from: Member(name: "lastLocation", latitude: lastLatitude, longitude: lastLongitude), to: Member(name: "presentLocation", latitude: presentLatitude, longitude: presentLongitude)) ?? 0.0) / 1000.0
                
                accumulatedDistance += addedDistance
                
                // check if we have crossed 1 km (round length)
                if accumulatedDistance >= roundLength {
                    
                    // speed of the last segment
                    let timeInSeconds = locations[index].timestamp.timeIntervalSince(locations[index-1].timestamp)
                    let kmPerSecond = addedDistance / timeInSeconds
                    
                    // time it took for the distance to 1.0 km
                    let distanceOverRoundLength = accumulatedDistance - roundLength
                    let distanceToRoundLength = addedDistance - distanceOverRoundLength
                    let secondsToRoundLength = distanceToRoundLength / kmPerSecond
                    
                    // new crossing date
                    let kmCrossingDate = locations[index-1].timestamp.addingTimeInterval(secondsToRoundLength)
                    
                    // calculate time from last time
                    let prettyTime = calculatePrettyTimeString(from: lastKmDate, to: kmCrossingDate)
                    timesArray.append(kmCrossingDate.timeIntervalSince(lastKmDate))
                    
                    // updating distances
                    numberOfKm += Int(roundLength)
                    accumulatedDistance -= roundLength
                    
                    roundsArray.append((String(numberOfKm), prettyTime))
                    
                    // updating the last km crossing date
                    lastKmDate = kmCrossingDate
                }
            }
            
            // also get the last distance
            let totalDistance = accumulatedDistance + Double(numberOfKm)
            
            if accumulatedDistance > 0.0 {
                let prettyTime = calculatePrettyTimeString(from: lastKmDate, to: locations.last!.timestamp)
                let timePerKilometer = locations.last!.timestamp.timeIntervalSince(lastKmDate) / accumulatedDistance
                let paceString = makePrettyMinutesString(timeInSeconds: timePerKilometer, paceFormat: false)
                let lastRoundTimeString = prettyTime + " (" + paceString + " /km)"
                roundsArray.append((String(format: "%.1f", totalDistance), lastRoundTimeString))
                
                timesArray.append((locations.last!.timestamp.timeIntervalSince(lastKmDate)) / accumulatedDistance)
            }
            
            var returnArray = roundsArray.map { ($0.0, $0.1, "")}
            
            // find the slowest and fastest rounds
            if let slowestKM = timesArray.max() {
                if let slowestIndex = timesArray.firstIndex(of: slowestKM) {
                    returnArray[slowestIndex].2 = "🐌"
                    
                    if timesArray.count > 2 {
                        let slowestTime = timesArray[slowestIndex]
                        timesArray[slowestIndex] = 0
                        if let secondSlowestKM = timesArray.max() {
                            if let secondSlowestIndex = timesArray.firstIndex(of: secondSlowestKM) {
                                returnArray[secondSlowestIndex].2 = "🐢"
                                timesArray[slowestIndex] = slowestTime
                            }
                        }
                    }
                }
            }
            
            if let fastestKM = timesArray.min() {
                if let fastestIndex = timesArray.firstIndex(of: fastestKM) {
                    returnArray[fastestIndex].2 = "🚀"
                    
                    if timesArray.count > 2 {
                        timesArray[fastestIndex] = 1000000
                        if let secondFastestKM = timesArray.min() {
                            if let secondFastestIndex = timesArray.firstIndex(of: secondFastestKM) {
                                returnArray[secondFastestIndex].2 = "🐇"
                            }
                        }
                    }
                }
            }
            
            return returnArray
        } else {
            return []
        }
    }
    
    /// calculating average pace
    func calculateAveragePace(statistic: RunStatistic) -> String {
        let totalCalculatedTime = (statistic.locationData.last?.timestamp ?? Date.now).timeIntervalSince(statistic.locationData.first?.timestamp ?? Date.now)
        let pace = totalCalculatedTime / (statistic.runDistance / 1000)
        let prettyPace = makePrettyMinutesString(timeInSeconds: pace, paceFormat: true)
        
        return prettyPace + " /km"
    }
    
    
    /// calculates time between dates and returns a pretty minutes time string
    private func calculatePrettyTimeString(from: Date, to: Date) -> String {
        let totalTime = to.timeIntervalSince(from)
        let prettyTime = makePrettyMinutesString(timeInSeconds: totalTime)
        return prettyTime
    }
    
    
    func calculateMaxAngle(angles: [MapAngle]) -> String {
        if angles.isEmpty { return "" }
        let numericAngles = angles.compactMap { angle -> Double? in
            let cleanedString = angle.angle.replacingOccurrences(of: "°", with: "").trimmingCharacters(in: .whitespaces)
            return Double(cleanedString)
        }
        
        guard let maxAngle = numericAngles.max() else {
            return ""
        }
        
        return String(format: "%.1f°", maxAngle)
    }
        
    /// calculates the new poly line number
    func calculatePolylineNumber(context: MapCameraUpdateContext, locations: [LocationData], maxPolylinesToShow: Int) -> Int {
        // count how many coordinates are visible for the camera
        let mapRect = context.rect
        var coordinatesVisible = 0
        
        for location in locations {
            if mapRect.contains(MKMapPoint(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))) {
                coordinatesVisible += 1
            }
        }
        
        if coordinatesVisible == 0 {
            return 0
        }
        
        let totalCoordinates = locations.count
        
        let visibleToTotalFactor = Double(totalCoordinates) / Double(coordinatesVisible)
        
        let newPolyLineNumber: Int
        if coordinatesVisible > maxPolylinesToShow {
            // show only max
            newPolyLineNumber = Int(round(Double(maxPolylinesToShow) * visibleToTotalFactor))
        } else {
            newPolyLineNumber = Int(round(Double(coordinatesVisible) * visibleToTotalFactor))
        }
        
        return newPolyLineNumber
    }
    
    /// creates polyline coordinates and colors
    func createPolylineData(locationData: [LocationData], numberOfElementsToKeep: Int, coordinatesCount: Int) async -> [PolylineData] {
        return createPolylineDataSync(locationData: locationData, numberOfElementsToKeep: numberOfElementsToKeep, coordinatesCount: coordinatesCount)
    }
    
    func createPolylineDataSync(locationData: [LocationData], numberOfElementsToKeep: Int, coordinatesCount: Int) -> [PolylineData] {
        guard numberOfElementsToKeep > 0 else {
            return []
        }
        var locationPairs = [(LocationData, LocationData)]()
        
        let stepSize = Double(coordinatesCount) / Double(numberOfElementsToKeep)
        
        for i in 0..<numberOfElementsToKeep - 1 {
            let index = Int(round(Double(i) * stepSize))
            let index2 = Int(round(Double(i + 1) * stepSize))
            if index != index2 && index2 < coordinatesCount {
                locationPairs.append((locationData[index], locationData[index2]))
            }
        }
                
        let locationSpeeds = locationPairs.map { calculateSpeedsOfLocationPairs(locationPair: $0) }
        let maxSpeed = locationSpeeds.max() ?? 1.0
        let quantizedSpeeds = locationSpeeds.map { $0 / maxSpeed }
        
        let lineColors = quantizedSpeeds.map { createColorFromQuantizedSpeed(speed: $0)}
        
        var polylineData = [PolylineData]()
        
        for (index, line) in locationPairs.enumerated() {
            let polyline = PolylineData(coordinates: [CLLocationCoordinate2D(latitude: line.0.latitude, longitude: line.0.longitude), CLLocationCoordinate2D(latitude: line.1.latitude, longitude: line.1.longitude)], strokeColor: lineColors[index])
            polylineData.append(polyline)
        }
        return polylineData
    }
    
    /// create an array for all the speeds of the location pairs
    private func calculateSpeedsOfLocationPairs(locationPair: (LocationData, LocationData)) -> Double {
        let distance = calculateDirectDistance(from: Member(name: "from", latitude: locationPair.0.latitude, longitude: locationPair.0.longitude), to: Member(name: "to", latitude: locationPair.1.latitude, longitude: locationPair.1.longitude)) ?? 0.0
        let time = locationPair.1.timestamp.timeIntervalSince(locationPair.0.timestamp)
        let speed = distance / time
        return speed
    }
    
    private func createColorFromQuantizedSpeed(speed: Double) -> Color {
        let hue = 0.33 * speed
        return Color(hue: hue, saturation: 1.0, brightness: 1.0)
    }
    
    
    /// create an array with colors for the gradient of a polyline
    func createGradientArray(for locations: [LocationData], numberOfElementsToKeep: Int) -> [Color] {
        let locationsCount = locations.count
        // create an array of all the location pairs
        var locationPairs = [(LocationData, LocationData)]()
        
        let stepSize = Double(locationsCount) / Double(numberOfElementsToKeep)
        
        for i in 0..<numberOfElementsToKeep - 1 {
            let index = Int(round(Double(i) * stepSize))
            let index2 = Int(round(Double(i + 1) * stepSize))
            // Ensure the index is within bounds of the array
            if index != index2 && index2 < locationsCount {
                locationPairs.append((locations[index], locations[index2]))
            }
        }
        
        let locationSpeeds = locationPairs.map { calculateSpeedsOfLocationPairs(locationPair: $0) }
        let maxSpeed = locationSpeeds.max() ?? 1.0
        let quantizedSpeeds = locationSpeeds.map { $0 / maxSpeed }
        let lineColors = quantizedSpeeds.map { createColorFromQuantizedSpeed(speed: $0)}
        
        return lineColors
    }
    
    /// tries to get a location name from coordinates
    func getNameOfLocation(location: LocationData, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
        // Perform reverse geocoding to get the address from coordinates
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                completion(nil)
                return
            }
            
            completion(placemark.locality)
        }
    }
    
    /// creates a date string from two dates
    func makeTimeIntervalDate(startDate: Date, endDate: Date, withYear: Bool = false) -> String {
        let dateFormatter = DateFormatter()
        if withYear {
            dateFormatter.dateFormat = "MMM dd YYYY HH:mm"
        } else {
            dateFormatter.dateFormat = "MMM dd HH:mm"
        }
        
        let startDateComponents = Calendar.current.dateComponents([.day, .month], from: startDate)
        let endDateComponents = Calendar.current.dateComponents([.day, .month], from: endDate)
        
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)
        
        if startDateComponents.day == endDateComponents.day {
            return "\(startString) - \(endString.suffix(5))"
        } else {
            return "\(startString) - \(endString)"
        }
    }
    
    /// returns time in minutes from two dates
    private func timeInMinutesFromDates(startDate: Date, finishDate: Date) -> Double {
        let timeInterval = finishDate.timeIntervalSince(startDate)
        let timeInMinutes = timeInterval / 60
        
        return timeInMinutes
    }
    
    /// calculates a total distance in meter and find the top speed from an array of locations
    private func calculateTotalDistanceAndTopSpeed(locations: [LocationData]) -> (totalDistance: Double, topSpeed: Double) {
        var totalDistance = 0.0
        var topSpeed = locations.first!.speed ?? 0.0
        
        for index in 1..<locations.count {
            // Update top speed
            if locations[index].speed ?? 0.0 > topSpeed {
                topSpeed = locations[index].speed!
            }
            
            // Update distance
            let lastLatitude = locations[index-1].latitude
            let lastLongitude = locations[index-1].longitude
            let presentLatitude = locations[index].latitude
            let presentLongitude = locations[index].longitude
            let addedDistance = (calculateDirectDistance(from: Member(name: "lastLocation", latitude: lastLatitude, longitude: lastLongitude), to: Member(name: "presentLocation", latitude: presentLatitude, longitude: presentLongitude)) ?? 0.0)
            
            totalDistance += addedDistance
        }
        
        if topSpeed == -1.0 {
            topSpeed = 0.0
        }
        
        // top speed calculation to km/h from m/s
        topSpeed *= 3.6
        
        return (totalDistance, topSpeed)
    }
    
    /// reverts all changes of the route
    func revertChangesForRoute(for statistic: RunStatistic, completion: @escaping (RunStatistic?) -> Void) {
        if let index = importedRuns.firstIndex(where: { $0.id == statistic.id }) {
            var statistic = statistic
            statistic.locationData = importedRuns[index].locations
            
            completion(statistic)
        } else {
            if HKHealthStore.isHealthDataAvailable() {
                loadWorkoutRouteFromID(id: statistic.id) { route in
                    if let route = route {
                        self.locationDataFromWorkoutRoute(route: route) { locationData in
                            var revertedRunStatistic = statistic
                            revertedRunStatistic.locationData = locationData
                            completion(revertedRunStatistic)
                        }
                    } else if let backup = self.backupWorkoutData.first(where: { $0.startDate == statistic.startDate }) {
                        completion(backup)
                } else {
                        completion(nil) // Return nil if the route is not found
                    }
                }
            } else {
                do {
                    // getting the runStatistics (if no health or for older files)
                    let url = try self.getDocumentsDirectory().appendingPathComponent(self.fileName)
                    let data = try Data(contentsOf: url)
                    let decodedStatistics = try JSONDecoder().decode([RunStatistic].self, from: data)
                    
                    if let ogRunStatistic = decodedStatistics.first(where: { $0.id == statistic.id }) {
                        var revertedRunStatistic = statistic
                        revertedRunStatistic.locationData = ogRunStatistic.locationData
                        
                        completion(revertedRunStatistic)
                    } else {
                        completion(nil)
                    }
                } catch {
                    print("Error loading runStatistics: \(error)")
                    completion(nil)
                }
            }
        }
        
    }
    
    /// checks if there is an edit for a statistic
    func hasEdits(for statistic: RunStatistic) -> Bool {
        if let editsIndex = runEdits.firstIndex(where: { $0.id == statistic.id }) {
            if let deletedLocations = runEdits[editsIndex].deletedLocations {
                if !deletedLocations.isEmpty {
                    return true
                }
            }
        }
        return false
    }
    
    /// set a new start point for a run statistic
    func setStart(for statistic: RunStatistic, coordinate: CLLocationCoordinate2D) async -> RunStatistic {
        // remove all points before the start
        if let startIndex = statistic.locationData.firstIndex(where: { $0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude }) {
            
            let newLocationData = Array(statistic.locationData[startIndex..<statistic.locationData.endIndex])
            
            // recalculate distance, max speed, etc.
            //            let startTime = newLocationData.first!.timestamp
            //            let finishTime = newLocationData.last!.timestamp
            //            let newRunTime = timeInMinutesFromDates(startDate: startTime, finishDate: finishTime)
            //            let distanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newLocationData)
            //            let newRunDistance = distanceAndSpeed.totalDistance
            //            let newTopSpeed = distanceAndSpeed.topSpeed
            //
            //            // editing the statistic
            var newStatistic = statistic
            //            newStatistic.runTime = newRunTime
            //            newStatistic.runDistance = newRunDistance
            //            newStatistic.topSpeed = newTopSpeed
            newStatistic.locationData = newLocationData
            //            newStatistic.startDate = startTime
            //            newStatistic.endDate = finishTime
            
            return newStatistic
            
            
        } else {
            return statistic
        }
        
    }
    
    /// set a new finish point for a run statistic
    func setFinish(for statistic: RunStatistic, coordinate: CLLocationCoordinate2D) async -> RunStatistic {
        // remove all points before the start
        if let finishIndex = statistic.locationData.lastIndex(where: { $0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude }) {
            
            let newLocationData = Array(statistic.locationData[statistic.locationData.startIndex...finishIndex])
            
            // recalculate distance, max speed, etc.
            //            let startTime = newLocationData.first!.timestamp
            //            let finishTime = newLocationData.last!.timestamp
            //            let newRunTime = timeInMinutesFromDates(startDate: startTime, finishDate: finishTime)
            //            let distanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newLocationData)
            //            let newRunDistance = distanceAndSpeed.totalDistance
            //            let newTopSpeed = distanceAndSpeed.topSpeed
            
            var newStatistic = statistic
            //            newStatistic.runTime = newRunTime
            //            newStatistic.runDistance = newRunDistance
            //            newStatistic.topSpeed = newTopSpeed
            newStatistic.locationData = newLocationData
            //            newStatistic.startDate = startTime
            //            newStatistic.endDate = finishTime
            
            return newStatistic
            
        } else {
            return statistic
        }
    }
    
    /// remove a point from a run statistic
    func removePoint(for statistic: RunStatistic, coordinate: CLLocationCoordinate2D) async -> RunStatistic {
        // remove all points before the start
        if let removeIndex = statistic.locationData.firstIndex(where: { $0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude }) {
            
            var newLocationData = statistic.locationData
            newLocationData.remove(at: removeIndex)
            
            // recalculate distance, max speed, etc.
            //            let startTime = newLocationData.first!.timestamp
            //            let finishTime = newLocationData.last!.timestamp
            //            let newRunTime = timeInMinutesFromDates(startDate: startTime, finishDate: finishTime)
            //            let distanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newLocationData)
            //            let newRunDistance = distanceAndSpeed.totalDistance
            //            let newTopSpeed = distanceAndSpeed.topSpeed
            
            var newStatistic = statistic
            //            newStatistic.runTime = newRunTime
            //            newStatistic.runDistance = newRunDistance
            //            newStatistic.topSpeed = newTopSpeed
            newStatistic.locationData = newLocationData
            //            newStatistic.startDate = startTime
            //            newStatistic.endDate = finishTime
            
            return newStatistic
            
        } else {
            return statistic
        }
    }
    
    // MARK: - Health
    
    let healthStore = HKHealthStore()
    
    private let typesToShare: Set = [
        HKQuantityType.workoutType(),
        HKSeriesType.workoutRoute()
    ]
    
    @Published var hasHealthActivated = false
    
    func requestHealthAuthorization() {
        
        let typesToRead: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if !success {
                print("Health Store authorization failed with error: \(String(describing: error))")
            }
            DispatchQueue.main.async {
                self.checkHealthKitAuthorizationStatus()
            }
        }
    }
    
    func checkHealthKitAuthorizationStatus() {
        var hasNotAuthorized = false
        
        for type in typesToShare {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                hasNotAuthorized = true
                requestHealthAuthorization()
                break
            }
        }
        hasHealthActivated = !hasNotAuthorized
    }
    
    
    // MARK: - Run
    
    @Published var activeRun: Run = Run(name: "", members: [], active: false)
    
    @Published var locationError = false
    
    var runTimer: Timer?
    
    /// creating a new run
    func startNewRun(name: String) async throws {
        
        let url = try createDWURL(endpoint: Endpoints.runs)
        
        // create a new DB run and upload
        let newRun = DBRun(id: UUID(), name: name)
        
        try await HTTPClient.shared.sendData(to: url, object: newRun, httpMethod: HTTPMethods.POST.rawValue)
        
        // add user to the run
        DispatchQueue.main.async {
//            self.user.onlyWatching = false
        }
        let updatedUser = Member(id: user.id, name: user.name, status: user.status, latitude: user.latitude, longitude: user.longitude, speed: user.speed, onlyWatching: false, createdOn: user.createdOn, lastUpdated: user.lastUpdated)
        try await addMembersToRun(members: [updatedUser], runID: newRun.id!)
        
        // updating the run name from the db
        let updatedRunName = try await getRunNameFromId(runId: newRun.id!)
        let updatedRun = Run(id: newRun.id, name: updatedRunName, members: [], active: true, startedOn: Date.now)
        
        // starting the action
        try await startActiveRun(run: updatedRun)
    }
    
    /// creates a random run name
    func createRandomRunName() -> String {
        let firstWords = ["dolphin", "shark", "turtle", "whale", "gust", "glide", "swell", "current", "breeze", "flow", "tailwind", "Gorgier", "Saint Blaise", "Neuchatel", "Hawaii", "Maui", "Oahu", "Kauai", "Molokai", "Lanai", "Niihau", "Kahoolawe", "Tenerife", "Portugal", "Italy", "Biel", "lake", "river", "puddle", "chocolate", "eagle", "Switzerland", "Netherlands", "Spain", "F-ONE", "Unifoil", "Lift", "Armstrong", "Vietnam", "shuttle", "hill", "Nazare", "Wave", "virtual", "perth", "casey", "mango", "flowy", "bump", "wet", "super", "mega"]
        let secondWords = ["paddle", "surf", "foiling", "flight", "foil", "soaring", "breaching", "kook", "cooking", "runners", "losers", "pro", "carve", "carving", "bomb", "bombing", "eagles", "frequent", "progressive", "freestyle", "backflip", "360"]
        let thirdWords = ["kooks", "crew", "run", "race", "club", "gang", "group", "school", "anonymous", "squad", "slicers", "flyers", "riders"]
        
        let name = "\(firstWords.randomElement()!) \(secondWords.randomElement()!) \(thirdWords.randomElement()!)".capitalized
        
        return name
    }
    
    private func getRunNameFromId(runId: UUID) async throws -> String {
        
        let runIDString = runId.uuidString
        
        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runIDString)
        
        let dbRunResponse: DBRun = try await HTTPClient.shared.fetchString(url: url)
        
        return dbRunResponse.name
        
    }
    
    /// joining a run
    func joinRun(name: String) async throws {
        
        // get run
        let runToJoin = try await getRunFromName(runName: name)
        
        // add user to the run
        DispatchQueue.main.async {
//            self.user.onlyWatching = false
        }
        let updatedUser = Member(id: user.id, name: user.name, status: user.status, latitude: user.latitude, longitude: user.longitude, speed: user.speed, onlyWatching: false, createdOn: user.createdOn, lastUpdated: user.lastUpdated)
        try await addMembersToRun(members: [updatedUser], runID: runToJoin.id!)
        
        
        // starting the action
        try await startActiveRun(run: runToJoin)
        
    }
    
    /// watching a run
    func watchRun(name: String) async throws {
        
        // get run
        let runToJoin = try await getRunFromName(runName: name)
        
        // add user to the run
        DispatchQueue.main.async {
//            self.user.onlyWatching = true
        }
        let updatedUser = Member(id: user.id, name: user.name, status: user.status, latitude: user.latitude, longitude: user.longitude, speed: user.speed, onlyWatching: true, createdOn: user.createdOn, lastUpdated: user.lastUpdated)
        try await addMembersToRun(members: [updatedUser], runID: runToJoin.id!)
        
        
        // starting the action
        try await startWatchingRun(run: runToJoin)
        
    }
    
    private func getRunFromName(runName: String) async throws -> Run {
        
        let url = try createDWURL(endpoint: Endpoints.runs + Endpoints.byname + "/" + runName)
        
        let dbRunResponse: DBRun = try await HTTPClient.shared.fetchString(url: url)
        
        let run = Run(id: dbRunResponse.id, name: runName, members: [], active: true, startedOn: dateFromString(dbRunResponse.startedOn ?? "2023-01-10T13:36:12Z"))
        
        return run
    }
    
    //    /// looking for an active run with the user in it, and starting the UI of the run up
    //    func loadAllRuns() async throws {
    //
    //        if let userIDString = user.id?.uuidString {
    //            let url = try createDWURL(endpoint: Endpoints.members + "/" + userIDString + Endpoints.runs)
    //
    //            let dbRunResponse: [DBRun] = try await HTTPClient.shared.fetch(url: url)
    //
    //            if !dbRunResponse.isEmpty {
    //                // request for location authorization
    //                locationManager?.requestWhenInUseAuthorization()
    //
    //                // remove user from all runs that are older than 24 hours, return array of active runs
    //                let runArray = try await findOldRunsAndRemoveUser(runList: dbRunResponse)
    //
    //                    // if more than 0 run, fill the all runs array and return
    //                    if runArray.count > 0 {
    //                        DispatchQueue.main.async {
    //                            self.allRuns = runArray
    //                            // Note: not sure why the task runs after the previous line, but it sure seems to.
    //                            Task {
    //                                do {
    //                                    try await self.loadMembersOfAllRuns()
    //                                } catch {
    //                                    print("Error loading members of all runs")
    //                                }
    //                            }
    //                        }
    //
    //                        // no runs? return
    //                    } else {
    //                        return
    //                    }
    //            }
    //        }
    //    }
    
    /// load run as active run, starting run up
    private func startActiveRun(run: Run) async throws {
        // request for location authorization
        locationManager?.requestWhenInUseAuthorization()
        
//        DispatchQueue.main.async {
//            
//            // start active run
//            self.activeRun.id = run.id
//            self.activeRun.name = run.name
//            self.activeRun.startedOn = run.startedOn
//            self.activeRun.active = true
//            
//            // check if we have authorization to see location and start location
//            self.checkAndStartLocationService()
//        }
        
    }
    
    /// load run as watching only run
    private func startWatchingRun(run: Run) async throws {
        
//        DispatchQueue.main.async {
//            // start active run
//            self.activeRun.id = run.id
//            self.activeRun.name = run.name
//            self.activeRun.startedOn = run.startedOn
//            self.activeRun.active = true
//            
//            // start download timer
//            self.startUploadDownloadTimer(onlyDownload: true)
//        }
        
    }
    
    //    /// removes user from array all runs
    //    func removeUserFromAllRuns() async throws {
    //        for run in allRuns {
    //            // remove user from all runs in the db
    //            do {
    //                try await removeUserFromRun(run: run)
    //            } catch {
    //                print("Error removing user from run \(run.name): \(error)")
    //            }
    //            // remove all runs in the model
    //            DispatchQueue.main.async {
    //                self.allRuns = []
    //            }
    //        }
    //    }
    
    /// stops the location service and resets the ignore var
    private func stopLocationService() {
        print("Stopping location tracking")
        self.locationManager?.stopUpdatingLocation()
        self.locationManager?.stopUpdatingHeading()
        ignoreFirstFewLocations = true
        resetKalmanFilter = true
        isUpdatingLocation = false
        lastAcceptedCollectionLocation = nil
        latestStatisticLocationData = nil
        resetPoorAccuracyFailOpen()
        
        // set location of user to nil
        self.user.latitude = nil
        self.user.longitude = nil
        self.user.speed = nil
    }
    
    /// checks and starts location service
    private func checkAndStartLocationService(cloudService: Bool = true) {
        if self.locationAuthorization {
            
            if !isUpdatingLocation {
                print("Starting location tracking")
                self.locationManager?.startUpdatingLocation()
                self.locationManager?.startUpdatingHeading()
                locationManagerStartTime = Date.now
                isUpdatingLocation = true
                lastAcceptedCollectionLocation = nil
                resetPoorAccuracyFailOpen()
            }
            
            if cloudService {
                // starting the upload/download timer
//                self.startUploadDownloadTimer()
            }
            
            // Ensure the timer is added to the current run loop
            //                            RunLoop.current.add(self.runTimer!, forMode: .default)
            //                        } else {
            //                            // show message can't activate location services -> either your device is in Airplane mode or the device doesn’t have the required hardware
            //                            self.locationError = true
            //                        }
            
            
        } else {
            // show location authorization request again
            self.locationManager?.requestWhenInUseAuthorization()
        }
    }
    
    //    /// removes user from all old runs and returns a list of new runs, sorted by newest
    //    private func findOldRunsAndRemoveUser(runList: [DBRun]) async throws -> [Run] {
    //        // turn db runs into runs
    //        let rawRunArray = runList.compactMap( { DBRun in
    //            Run(
    //                id: DBRun.id,
    //                name: DBRun.name,
    //                members: [],
    //                active: true,
    //                startedOn: dateFromString(DBRun.startedOn ?? "2023-01-10T13:36:12Z")
    //            )
    //        } )
    //        // filter all old runs
    //        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
    //        let runIdsToRemoveUser = rawRunArray.filter { $0.startedOn! < twentyFourHoursAgo}
    //
    //        // remove user from all old runs (and delete run if empty)
    //        for run in runIdsToRemoveUser {
    //            do {
    //                try await removeUserFromRun(run: run)
    //            } catch {
    //                print("Error removing user from run: \(error)")
    //            }
    //
    //        }
    //
    //        // return the newer runs, sorted by newest
    //        let newRuns = rawRunArray.filter { $0.startedOn! >= twentyFourHoursAgo }.sorted(by: { $0.startedOn! > $1.startedOn! })
    //        return newRuns
    //    }
    
    
    /// starts our upload and download timer
    private func startUploadDownloadTimer(onlyDownload: Bool = false) {
        // down and upload for the first time
        Task {
            await self.upDownloadManager()
        }
        
        // start the timer
        self.runTimer = Timer.scheduledTimer(withTimeInterval: Constants.locationTimerInterval, repeats: true) { _ in
            Task {
                await self.upDownloadManager(onlyDownload: onlyDownload)
            }
        }
    }
    
    
    /// uploads user location, and downloads the other members
    func upDownloadManager(onlyDownload: Bool = false) async {
        print("UpDownload is running")
        // Upload user location
        if onlyDownload == false {
            do {
                try await uploadUserLocation()
            } catch {
                print("Error uploading user location: \(error)")
            }
        }
        
        // After uploading, load run members
        do {
            try await loadRunMembers(notUpdatingMemberStatistic: onlyDownload)
        } catch {
            print("Error loading run members: \(error)")
        }
    }
    
    /// updates the user in db
    func uploadUserLocation(makeItNil: Bool = false) async throws {
        print("uploading user")
        let url = try createDWURL(endpoint: Endpoints.members)
        
        let userToUpdate = makeItNil ? Member(id: user.id, name: user.name, latitude: nil, longitude: nil) : self.user
        
        try await HTTPClient.shared.sendData(to: url, object: userToUpdate, httpMethod: HTTPMethods.PUT.rawValue)
    }
    
    /// removes user from the active run or deletes run if user is last member
    private func removeUserFromRun(run: Run) async throws {
        guard let runID = run.id else {
            print("Error: No active run ID!")
            return
        }
        
        // remove user from run
        guard let userID = user.id else {
            print("Error: No user ID!")
            return
        }
        
        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members + "/" + userID.uuidString)
        
        do {
            try await HTTPClient.shared.delete(url: url)
            print("removed user from run")
        } catch {
            print("Error deleting user from run: \(error)")
        }
        
        
        // check if user was last member, delete if was
        if run.members.count == 0 {
            
            let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString)
            
            do {
                try await HTTPClient.shared.delete(url: url)
                print("deleted empty run")
            } catch {
                print("Error deleting run: \(error)")
            }
        }
        
    }
    
    /// change user from active runner to only watching during a run
    func changeFromRunningToWatching() {
        DispatchQueue.main.async {
            
            // stop timer
            self.runTimer?.invalidate()
            self.runTimer = nil
            
            // stop location and heading updating - only if the self tracking is not on
            if !self.activeStatistics {
                self.stopLocationService()
            }
            
            self.startUploadDownloadTimer(onlyDownload: true)
            
        }
    }
    
    /// quit active run: removes user from run, stops run timer, stops updating location, stops updating header, sets location, speed and heading to nil and updates the user in the DB to that
    func quitActiveRun() async throws {
        
        // reset the active run var
//        DispatchQueue.main.async {
//            
//            // make run inactive, keeping the id
////            self.activeRun = Run(name: "", members: self.activeRun.members, active: false)
//            
//            self.runTimer?.invalidate()
//            self.runTimer = nil
//            
//            // stop location and heading updating - only if the self tracking is not on
//            if !self.activeStatistics {
//                self.stopLocationService()
//            }
//            
//        }
        // remove user from run / delete run if user is last member
//        do {
//            try await removeUserFromRun(run: activeRun)
//            // remove members from active run (probably not necessary)
//            DispatchQueue.main.async {
//                self.activeRun.members = []
//            }
//        } catch {
//            print("Error removing user from run: \(error)")
//        }
//        
//        // update the user location of nil on db for maximum privacy
//        do {
//            try await uploadUserLocation(makeItNil: true)
//        } catch {
//            print("Error uploading user location: \(error)")
//        }
    }
    
    
    /// loading members of active run
    func loadRunMembers(notUpdatingMemberStatistic: Bool = true) async throws {
//        print("loading members")
//        guard let runID = activeRun.id else {
//            print("Error: No active run ID!")
//            return }
//        
//        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members)
//        
//        let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
//        
//        DispatchQueue.main.async {
//            self.activeRun.members = membersResponse.filter { $0.id != self.user.id }
//            if notUpdatingMemberStatistic == false {
//                self.updateMemberStatistics()
//            }
//        }
    }
    
    /// adding members to an active run
    func addMembersToRun(members: [Member], runID: UUID) async throws {
        // add the members to the active run on the db
        for member in members {
            let newBaseURL = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members + "/" + member.id!.uuidString)
            
            try await HTTPClient.shared.postURL(url: newBaseURL)
        }
    }
    
    
    
    
    // MARK: - User
    
    @Published var user: Member = Member(id: nil, name: "", status: "All good.")
    @Published var trueHeading: Double = 0.0
    
    func saveUser() {
        let keychain = KeychainSwift()
        if let data = try? JSONEncoder().encode(user) {
            keychain.set(data, forKey: Constants.keychainKey)
        }
    }
    
    func loadUser() {
        let keychain = KeychainSwift()
        if let data = keychain.getData(Constants.keychainKey),
           let loadedUser = try? JSONDecoder().decode(Member.self, from: data) {
            user = loadedUser
        }
    }
    
    func addUserToDB() async throws {
        let url = try createDWURL(endpoint: Endpoints.members)
        
        let member = Member(id: user.id, name: user.name)
        
        try await HTTPClient.shared.sendData(to: url, object: member, httpMethod: HTTPMethods.POST.rawValue)
    }
    
    func checkAndUpdateUserInDB() async throws {
        let url = try createDWURL(endpoint: Endpoints.checkUpdateMembers)
        
        try await HTTPClient.shared.sendData(to: url, object: user, httpMethod: HTTPMethods.POST.rawValue)
    }
    
    func deleteUserFromDB() async throws {
        if let userIDString = user.id?.uuidString {
            let url = try createDWURL(endpoint: Endpoints.checkUpdateMembers + "/" + userIDString)
            
            try await HTTPClient.shared.delete(url: url)
        }
        
    }
    
    
    
    // MARK: - Location
    
    private var locationManager: CLLocationManager?
    var isUpdatingLocation = false
    
    private var ignoreFirstFewLocations = true
    private let secondsWeIgnoreLocations = 5.0
    private var locationManagerStartTime = Date.distantPast
    private var lastAcceptedCollectionLocation: CLLocation?
    private var poorAccuracyStreakStartTime: Date?
    private var isFailingOpenForPoorAccuracy = false
    
    // Kalman Filter
    var resetKalmanFilter: Bool = false
    var kalmanFilter: HCKalmanAlgorithm?
    @Published var rValue = 1.0
    @Published var sigma = 0.6
    
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.activityType = .fitness
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // Location Authorization
    private var locationAuthorization = false
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            // Permission granted, start location updates
            locationAuthorization = true
        } else if status == .notDetermined {
            // Location access not determined, request permission
            locationManager?.requestWhenInUseAuthorization()
        } else {
            // Handle denied or restricted permission
            locationAuthorization = false
        }
    }
    
    // Heading
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.trueHeading = Double(newHeading.trueHeading)
        }
    }
    
    // Location and Speed
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Check if locations array is empty
        guard !locations.isEmpty else {
            logError("Received empty locations array from location manager")
            return
        }
        
        // ignoring the locations for a few seconds
        if ignoreFirstFewLocations {
            
            if locationManagerStartTime.addingTimeInterval(secondsWeIgnoreLocations) < Date.now || locations.last!.horizontalAccuracy < 5.1 {
                ignoreFirstFewLocations = false
            }
            
        } else {
            let acceptedLocations = filterObviousGPSJumps(from: locations)
            guard let newLocation = acceptedLocations.last else {
                return
            }
            
            // Check for poor accuracy
            if newLocation.horizontalAccuracy > Constants.minHorizontalAccuracy {
                logError("Poor location accuracy: \(newLocation.horizontalAccuracy)m (threshold: \(Constants.minHorizontalAccuracy)m)")
            }
            
            // Check for invalid coordinates
            if !CLLocationCoordinate2DIsValid(newLocation.coordinate) {
                logError("Invalid coordinates received: lat=\(newLocation.coordinate.latitude), lon=\(newLocation.coordinate.longitude)")
                return
            }
            
            // Check for stale location data
            if newLocation.timestamp.timeIntervalSinceNow < -30 {
                logError("Received stale location data: timestamp is \(abs(newLocation.timestamp.timeIntervalSinceNow)) seconds old")
            }
            
            if collectRawGPS {
                resetPoorAccuracyFailOpen()
                
                routeBuilder?.insertRouteData(acceptedLocations) { (success, error) in
                    if !success {
                        let errorMessage = error?.localizedDescription ?? "Unknown error"
                        self.logError("Failed to insert raw GPS route data: \(errorMessage)")
                    }
                }
                
                DispatchQueue.main.async {
                    let locationData = self.makeLocationData(from: newLocation)
                    let speed = locationData.speed ?? 0.0
                    
                    self.user.latitude = newLocation.coordinate.latitude
                    self.user.longitude = newLocation.coordinate.longitude
                    self.user.speed = speed
                    self.latestStatisticLocationData = locationData
                    
                    self.locationAccuracy = newLocation.horizontalAccuracy
                    
                    self.updateStatistic(with: locationData)
                }
                
            } else {
                let canFailOpenForPoorAccuracy = shouldFailOpenForPoorAccuracy(newLocation)
                
                if kalmanFilter == nil {
                    if newLocation.horizontalAccuracy <= Constants.minHorizontalAccuracy {
                        // Check if rValue and sigma are properly set
                        if rValue <= 0 {
                            logError("Invalid rValue for Kalman filter: \(rValue)")
                        }
                        if sigma <= 0 {
                            logError("Invalid sigma for Kalman filter: \(sigma)")
                        }
                        
                        // setting the rValue of the Kalman filter. Higher values will give higher roundness to trajectories.
                        self.kalmanFilter?.rValue = rValue
                        self.kalmanFilter?.sigma = sigma
                        
                        // initializing the kalman filter
                        self.kalmanFilter = HCKalmanAlgorithm(initialLocation: newLocation)
                        
                        // Check if Kalman filter was successfully created
                        if self.kalmanFilter == nil {
                            logError("Failed to initialize Kalman filter with location: \(newLocation)")
                            return
                        }
                        
                        let startLocation = CLLocation(
                            coordinate: newLocation.coordinate,
                            altitude: newLocation.altitude,
                            horizontalAccuracy: newLocation.horizontalAccuracy,
                            verticalAccuracy: newLocation.verticalAccuracy,
                            course: newLocation.course,
                            speed: newLocation.speed,
                            timestamp: newLocation.timestamp
                        )
                    
                        routeBuilder?.insertRouteData([startLocation]) { (success, error) in
                            if !success {
                                let errorMessage = error?.localizedDescription ?? "Unknown error"
                                self.logError("Failed to insert Kalman start location: \(errorMessage)")
                            }
                        }
                    
                        DispatchQueue.main.async {
                            let locationData = self.makeLocationData(from: newLocation)
                            let speed = locationData.speed ?? 0.0
                            
                            self.user.latitude = newLocation.coordinate.latitude
                            self.user.longitude = newLocation.coordinate.longitude
                            self.user.speed = speed
                            self.latestStatisticLocationData = locationData
                            
                            self.locationAccuracy = newLocation.horizontalAccuracy
                            
                            self.updateStatistic(with: locationData)
                        }
                    } else if canFailOpenForPoorAccuracy {
                        publishRawLocationFallback(newLocation)
                    } else {
                        logError("Cannot initialize Kalman filter - accuracy too poor: \(newLocation.horizontalAccuracy)m")
                    }
                } else {
                    guard let kalmanFilter = self.kalmanFilter else {
                        logError("Kalman filter became nil unexpectedly")
                        return
                    }
                    
                    if resetKalmanFilter == true {
                        if newLocation.horizontalAccuracy <= Constants.minHorizontalAccuracy {
                            
                            // Check parameter validity before reset
                            if rValue <= 0 {
                                logError("Invalid rValue for Kalman filter reset: \(rValue)")
                            }
                            if sigma <= 0 {
                                logError("Invalid sigma for Kalman filter reset: \(sigma)")
                            }
                            
                            // two of these four are not needed, but save is save
                            self.kalmanFilter?.rValue = rValue
                            self.kalmanFilter?.sigma = sigma
                            kalmanFilter.rValue = rValue
                            kalmanFilter.sigma = sigma
                            
                            kalmanFilter.resetKalman(newStartLocation: newLocation)
                            
                            resetKalmanFilter = false
                        } else if canFailOpenForPoorAccuracy {
                            publishRawLocationFallback(newLocation)
                        }
                        
                    } else {
                        if newLocation.horizontalAccuracy <= Constants.minHorizontalAccuracy {
                            
                            var kalmanLocation = kalmanFilter.processState(currentLocation: newLocation)
                            
                            // Validate Kalman filter output
                            if !CLLocationCoordinate2DIsValid(kalmanLocation.coordinate) {
                                logError("Kalman filter produced invalid coordinates: lat=\(kalmanLocation.coordinate.latitude), lon=\(kalmanLocation.coordinate.longitude)")
                                return
                            }
                            
                            kalmanLocation = CLLocation(
                                coordinate: kalmanLocation.coordinate,
                                altitude: kalmanLocation.altitude,
                                horizontalAccuracy: kalmanLocation.horizontalAccuracy,
                                verticalAccuracy: kalmanLocation.verticalAccuracy,
                                course: kalmanLocation.course,
                                speed: newLocation.speed,
                                timestamp: kalmanLocation.timestamp
                            )
                            
                            routeBuilder?.insertRouteData([kalmanLocation]) { (success, error) in
                                if !success {
                                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                                    self.logError("Failed to insert Kalman filtered location: \(errorMessage)")
                                }
                            }
                        
                            DispatchQueue.main.async {
                                let locationData = self.makeLocationData(from: kalmanLocation, speed: newLocation.speed)
                                let speed = locationData.speed ?? 0.0
                                
                                self.user.latitude = kalmanLocation.coordinate.latitude
                                self.user.longitude = kalmanLocation.coordinate.longitude
                                self.user.speed = speed
                                self.latestStatisticLocationData = locationData
                                
                                self.locationAccuracy = newLocation.horizontalAccuracy
                                
                                self.updateStatistic(with: locationData)
                            }
                        } else if canFailOpenForPoorAccuracy {
                            publishRawLocationFallback(newLocation)
                        } else {
                            logError("Skipping location update - accuracy too poor for Kalman processing: \(newLocation.horizontalAccuracy)m")
                        }
                    }
                }
            }
        }
    }
    
    private func filterObviousGPSJumps(from locations: [CLLocation]) -> [CLLocation] {
        var acceptedLocations = [CLLocation]()
        
        for location in locations {
            guard !shouldDiscardObviousGPSJump(location) else {
                continue
            }
            
            acceptedLocations.append(location)
            lastAcceptedCollectionLocation = location
        }
        
        return acceptedLocations
    }
    
    private func shouldDiscardObviousGPSJump(_ location: CLLocation) -> Bool {
        guard let lastAcceptedCollectionLocation else {
            return false
        }
        
        let timeInterval = location.timestamp.timeIntervalSince(lastAcceptedCollectionLocation.timestamp)
        if timeInterval > Constants.maxObviousGPSJumpTimeInterval {
            return false
        }
        
        let distance = location.distance(from: lastAcceptedCollectionLocation)
        if distance > Constants.maxObviousGPSJumpDistance {
            logError("Discarding obvious GPS jump of \(Int(distance.rounded()))m")
            return true
        }
        
        return false
    }

    private func shouldFailOpenForPoorAccuracy(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > Constants.minHorizontalAccuracy else {
            resetPoorAccuracyFailOpen()
            return false
        }
        
        if isFailingOpenForPoorAccuracy {
            return true
        }
        
        if poorAccuracyStreakStartTime == nil {
            poorAccuracyStreakStartTime = location.timestamp
        }
        
        let poorAccuracyDuration = location.timestamp.timeIntervalSince(poorAccuracyStreakStartTime ?? location.timestamp)
        if poorAccuracyDuration >= Constants.poorAccuracyFailOpenTimeInterval {
            isFailingOpenForPoorAccuracy = true
            logError("Failing open for poor GPS accuracy at \(Int(location.horizontalAccuracy.rounded()))m")
            return true
        }
        
        return false
    }

    private func resetPoorAccuracyFailOpen() {
        poorAccuracyStreakStartTime = nil
        isFailingOpenForPoorAccuracy = false
    }

    private func publishRawLocationFallback(_ location: CLLocation) {
        routeBuilder?.insertRouteData([location]) { (success, error) in
            if !success {
                let errorMessage = error?.localizedDescription ?? "Unknown error"
                self.logError("Failed to insert fail-open location: \(errorMessage)")
            }
        }
        
        DispatchQueue.main.async {
            let locationData = self.makeLocationData(from: location)
            let speed = locationData.speed ?? 0.0
            
            self.user.latitude = location.coordinate.latitude
            self.user.longitude = location.coordinate.longitude
            self.user.speed = speed
            self.latestStatisticLocationData = locationData
            
            self.locationAccuracy = location.horizontalAccuracy
            
            self.updateStatistic(with: locationData)
        }
    }
    
    private func makeLocationData(from location: CLLocation, speed: Double? = nil) -> LocationData {
        let resolvedSpeed = speed ?? location.speed
        let normalizedSpeed = max(resolvedSpeed, 0.0)
        if resolvedSpeed < 0.0 {
            logError("Received negative speed value: \(resolvedSpeed) m/s, setting to 0.0")
        }
        
        return LocationData(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude.isFinite ? location.altitude : nil,
            speed: normalizedSpeed,
            verticalAccuracy: location.verticalAccuracy >= 0 && location.verticalAccuracy.isFinite ? location.verticalAccuracy : nil
        )
    }
    
    // MARK: - Kalman Filter Tests (Developer Mode)
    
    @Published var testStatistics = [RunStatistic]()
    @Published var collectRawGPS = false
    @Published var developerMode = false
    
    /// creating a filtered kalman locations thing
    func createFilteredLocations(statisticsData: RunStatistic, sigma: Double, rValue: Double) -> RunStatistic {
        var updatedStatistics = statisticsData
        updatedStatistics.locationData = []
        updatedStatistics.runDistance = 0.0
        
        for location in statisticsData.locationData {
            if kalmanFilter == nil {
                // setting the rValue of the Kalman filter. Higher values will give higher roundness to trajectories.
                self.kalmanFilter?.rValue = rValue
                self.kalmanFilter?.sigma = sigma
                
                // initializing the kalman filter
                self.kalmanFilter = HCKalmanAlgorithm(initialLocation: CLLocation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), altitude: 440, horizontalAccuracy: 4.7, verticalAccuracy: 3.5, timestamp: location.timestamp))
                
                
            } else {
                if let kalmanFilter = self.kalmanFilter {
                    if resetKalmanFilter == true {
                        self.kalmanFilter?.rValue = rValue
                        self.kalmanFilter?.sigma = sigma
                        kalmanFilter.rValue = rValue
                        kalmanFilter.sigma = sigma
                        
                        kalmanFilter.resetKalman(newStartLocation: CLLocation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), altitude: 440, horizontalAccuracy: 4.7, verticalAccuracy: 3.5, timestamp: location.timestamp))
                        
                        resetKalmanFilter = false
                        
                    }
                    
                    else {
                        let kalmanLocation = kalmanFilter.processState(currentLocation: CLLocation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), altitude: 440, horizontalAccuracy: 4.7, verticalAccuracy: 3.5, timestamp: location.timestamp))
                        let newLocation = LocationData(timestamp: location.timestamp, latitude: kalmanLocation.coordinate.latitude, longitude: kalmanLocation.coordinate.longitude, altitude: kalmanLocation.altitude)
                        
                        if let lastData = updatedStatistics.locationData.last {
                            
                            // calculate distance from location
                            let lastLatitude = lastData.latitude
                            let lastLongitude = lastData.longitude
                            let addedDistance = calculateDirectDistance(from: Member(name: "lastLocation", latitude: lastLatitude, longitude: lastLongitude), to: Member(name: "newLocation", latitude: newLocation.latitude, longitude: newLocation.longitude)) ?? 0.0
                            
                            updatedStatistics.runDistance += addedDistance
                        }
                        
                        updatedStatistics.locationData.append(newLocation)
                    }
                }
            }
        }
        
        // clean up
        resetKalmanFilter = true
        
        return updatedStatistics
    }
    
    /// making different kalman filter statistics
    func makingKalmanVersions(statistic: RunStatistic) -> [RunStatistic] {
        // try sigma 0.0625 up
        // try rValue 29 down
        // TODO: somehow give out a list of sigma and rValue
        var resultingStatistics = [RunStatistic]()
        
        for sigma in sigmas {
            for rValue in rValues {
                let newLocations = createFilteredLocations(statisticsData: statistic, sigma: sigma, rValue: rValue)
                resultingStatistics.append(newLocations)
            }
        }
        
        return resultingStatistics
        
    }
    
    /// making strings with sigma an rValues
    func makingSigmaAndRs() -> [String] {
        var strings = [String]()
        for sigma in sigmas {
            for rValue in rValues {
                let newString = "sig: \(sigma), r: \(rValue)"
                strings.append(newString)
            }
        }
        return strings
    }
    
    /// different sigmas and rvalues
    let sigmas = [0.01, 0.03, 0.0625, 0.25, 0.5, 0.6, 0.7, 0.8, 0.9]
    let rValues = [42, 35, 29.0, 24.0, 15, 9, 1]
    #endif
    // MARK: - In App Purchases
    
    let freeTrackerSessionsNumber = 8
    
    @AppStorage("sessionCounter") var trackerSessionsCount = 0
    @AppStorage("Premium") var hasPurchasedPremium = false
    @Published var purchasedProducts = [Product]()
    @Published var premiumProducts: [Product] = []
    @Published var subscriptionRenewalDate: Date? = nil
    @Published var nextBillingText = ""
    @Published var showUpgradeSheet = false
    @Published var statisticsCount = 0
    @Published var unableToLoadProducts = false
    @AppStorage("editCounter") var editCounter = 0
    var forcePremiumForScreenshots = false
    
    var updateListenerTask: Task<Void, Error>? = nil
    
    @MainActor
    func loadProductIdentifiersAndRequestProducts() async {
            guard let url = Bundle.main.url(forResource: "product_ids", withExtension: "plist") else {
                fatalError("Unable to resolve url for in the bundle.")
            }
            do {
                unableToLoadProducts = false
                let data = try Data(contentsOf: url)
                if let productIdentifiers = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String] {
                    await requestProducts(productIdentifiers: productIdentifiers)
                }
            } catch {
                unableToLoadProducts = true
                print("\(error.localizedDescription)")
            }
        }
    
    private func requestProducts(productIdentifiers: [String]) async {
        do {
            let products = try await Product.products(for: productIdentifiers)
            await updateProducts(products)
        } catch {
            print("Failed product request from the App Store server. \(error)")
            await markProductsAsUnavailable()
        }
    }

    @MainActor
    private func updateProducts(_ products: [Product]) {
        self.premiumProducts = products
    }

    @MainActor
    private func markProductsAsUnavailable() {
        self.unableToLoadProducts = true
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification.")
                }
            }
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        if appOpened > 0 && appOpened % 10 == 0 && self.currentAppVersion != self.lastVersionPromptedForReview  {
            self.showPromptForReview = true
            // The app already displayed the rating and review request view. Store this current version.
            self.lastVersionPromptedForReview = self.currentAppVersion
        }

        if forcePremiumForScreenshots {
            purchasedProducts = []
            hasPurchasedPremium = true
            showUpgradeSheet = false
            statisticsCount = max(statisticsCount, runStatistics.count)
            return
        }
        
        var currentEntitledPurchases: [Product] = []
        subscriptionRenewalDate = nil

        // Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                // Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)

                // Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .nonConsumable:
                    if let goat = premiumProducts.first(where: { $0.id == transaction.productID }) {
                        currentEntitledPurchases.append(goat)
                        nextBillingText = await createNextBillingText(product: goat)
                    }
                case .nonRenewable:
                    // we don't have this in our purchases
                    break
                case .autoRenewable:
                    if let subscription = premiumProducts.first(where: { $0.id == transaction.productID }) {
                        currentEntitledPurchases.append(subscription)
                        if let renewalDate = transaction.expirationDate {
                                subscriptionRenewalDate = renewalDate
                        }
                        nextBillingText = await createNextBillingText(product: subscription)
                    }
                default:
                    break
                }
            } catch {
                print()
            }
        }
        
        // Update the store information with the purchased products.
        purchasedProducts = currentEntitledPurchases
        hasPurchasedPremium = !currentEntitledPurchases.isEmpty
    }
    
    func purchase(product: Product) async throws -> Transaction? {
        // Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Check whether the transaction is verified. If it isn't,
            // this function rethrows the verification error.
            let transaction = try checkVerified(verification)

            // The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()

            // Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    func createImageForPurchasedProduct(product: Product? = nil) -> Image {
        let id = product?.id ?? purchasedProducts.first?.id
        if let id = id {
            if id == "com.project7iii.tracker.goat" {
                return Image("poseidonGoat")
            } else if id == "com.project7iii.tracker.weekend_warrior" {
                return Image("weekendWarrior")
            }
        }
        return Image("kook")
    }
    
    
    private func createNextBillingText(product: Product) async -> String {
            if product.id == "com.project7iii.tracker.goat" {
                return "Lifetime"
            } else {
                if let date = subscriptionRenewalDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    let renewalDateString = dateFormatter.string(from: date)
                    
                    if let willRenew = await isWillRenew(product: product), willRenew == false {
                        return "Expires: \(renewalDateString)"
                    } else {
                        return "Next billing date: \(renewalDateString)"
                    }                    
                }
                return ""
            }
        
    }
    
    func isWillRenew(product: Product) async -> Bool? {
        guard let SubscriptionGroupStatus = try? await product.subscription?.status.first else {
            print("There is no AutoRenewable Group")
            return nil
        }
        
        guard case .verified(let renewalInfo) = SubscriptionGroupStatus.renewalInfo else {
            print("The App Store could not verify your subscription status.")
            return nil
        }
        return renewalInfo.willAutoRenew
    }
    
    // MARK: - Review
    
    /// The most recent app version that prompts for a review.
    @AppStorage("lastVersionPromptedForReview") var lastVersionPromptedForReview = ""
    @AppStorage("timesOpened") var appOpened = 0
    @Published var showPromptForReview = false
    let currentAppVersion: String = {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "Unknown"
        }
        return version
    }()
    
    let currentAppBuild: String = {
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return "" // fallback if build missing
        }
        return "(\(build))"
    }()
    
    // MARK: - News Section
    @AppStorage("lastVersionNewsClosed") var lastVersionNewsClosed = ""
    
    #if os(iOS)
    // MARK: - GPX Import
    
    var importedRuns = [ImportRun]()
    
    private func loadImportedRunsFromDisk() {
        do {
            let url = try self.getDocumentsDirectory().appendingPathComponent(self.importFileName)
            let data = try Data(contentsOf: url)
            let decodedStatistics = try JSONDecoder().decode([ImportRun].self, from: data)
            importedRuns = decodedStatistics
        } catch {
            print("Error loading imported runs: \(error)")
        }
    }
    
    private func saveImportedRunsToDisk() {
        do {
            let url = try self.getDocumentsDirectory().appendingPathComponent(self.importFileName)
            let data = try JSONEncoder().encode(importedRuns)
            try data.write(to: url)
        } catch {
            print("Error saving imported runs: \(error)")
        }
    }

    func exportHealthKitRunsForFakeData(year: Int = 2025) async throws -> URL {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw FakeDataExportError.noHealthKitData
        }

        let workouts = try await loadWorkoutsFromHealthKit(year: year)
        guard !workouts.isEmpty else {
            throw FakeDataExportError.noRunsFound(year: year)
        }

        var exportedRuns: [ImportRun] = []
        for workout in workouts {
            if let run = try await makeImportRunFromHealthWorkout(workout) {
                exportedRuns.append(run)
            }
        }

        guard !exportedRuns.isEmpty else {
            throw FakeDataExportError.noExportableRuns(year: year)
        }

        let dashboardManager = TrackedElementsManager()
        let screenshotBundle = buildScreenshotFakeDataBundle(
            from: exportedRuns,
            year: year,
            dashboards: dashboardManager.dashboards,
            widgetDashboardIds: dashboardManager.widgetDashboardIds
        )

        let outputURL = try getDocumentsDirectory().appendingPathComponent("AppStoreScreenshotData-\(year).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(screenshotBundle)
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func buildScreenshotFakeDataBundle(
        from runs: [ImportRun],
        year: Int,
        dashboards: [Dashboard],
        widgetDashboardIds: [UUID]
    ) -> ScreenshotFakeDataBundle {
        var preparedRuns = runs.enumerated().map { normalizeScreenshotRun($0.element, index: $0.offset, year: year) }
        preparedRuns.sort { ($0.startLocation?.timestamp ?? $0.locations.first?.timestamp ?? .distantPast) > ($1.startLocation?.timestamp ?? $1.locations.first?.timestamp ?? .distantPast) }
        let existingRunEdits = Dictionary(uniqueKeysWithValues: runEdits.map { ($0.id, $0) })

        let dashboardSeed = dashboards.isEmpty ? screenshotFallbackDashboards(referenceYear: year) : dashboards
        let widgetSeed = widgetDashboardIds.isEmpty ? dashboardSeed.map(\.id) : widgetDashboardIds.filter { id in
            dashboardSeed.contains(where: { $0.id == id })
        }

        var featured = ScreenshotFeaturedRuns()

        featured.angleRunID = screenshotAngleRun(from: preparedRuns)?.id
        if featured.angleRunID == nil, let synthetic = makeSyntheticRun(
            from: preparedRuns.first(where: { ($0.workoutType ?? .surf) == .parawing || ($0.workoutType ?? .surf) == .dWParawing }) ?? preparedRuns.first,
            preferredDate: screenshotDate(year: year, month: 6, day: 17, hour: 17, minute: 40),
            workoutType: .parawing,
            locationString: preferredRoutePlaces(from: valueCounts(from: preparedRuns.compactMap(\.locationString))).first ?? "Saint-Aubin-Sauges",
            tags: ["#angle", "#parawing", "#screenshots"],
            minimumDistance: 12_000,
            minimumTopSpeed: 20
        ) {
            preparedRuns.append(synthetic)
            featured.angleRunID = synthetic.id
        }

        featured.parawingRunID = screenshotParawingRun(from: preparedRuns)?.id
        if featured.parawingRunID == nil, let synthetic = makeSyntheticRun(
            from: preparedRuns.first(where: { ($0.workoutType ?? .surf) == .dWParawing }) ?? preparedRuns.first(where: { ($0.workoutType ?? .surf).angleSport }) ?? preparedRuns.first,
            preferredDate: screenshotDate(year: year, month: 2, day: 2, hour: 12, minute: 7),
            workoutType: .parawing,
            locationString: preferredRoutePlaces(from: valueCounts(from: preparedRuns.compactMap(\.locationString))).first ?? "Saint-Aubin-Sauges",
            tags: ["#parawing", "#angle", "#screenshots"],
            minimumDistance: 9_470,
            minimumTopSpeed: 16
        ) {
            preparedRuns.append(synthetic)
            featured.parawingRunID = synthetic.id
        }

        featured.upDownwindParawingRunID = preparedRuns.first(where: { $0.workoutType == .paraUpDown })?.id
        if featured.upDownwindParawingRunID == nil, let synthetic = makeSyntheticRun(
            from: preparedRuns.first(where: { $0.id == featured.parawingRunID }) ?? preparedRuns.first,
            preferredDate: screenshotDate(year: year, month: 3, day: 8, hour: 13, minute: 14),
            workoutType: .paraUpDown,
            locationString: preferredRoutePlaces(from: valueCounts(from: preparedRuns.compactMap(\.locationString))).first ?? "Saint-Aubin-Sauges",
            tags: ["#udw", "#parawing", "#screenshots"],
            minimumDistance: 14_200,
            minimumTopSpeed: 16
        ) {
            preparedRuns.append(synthetic)
            featured.upDownwindParawingRunID = synthetic.id
        }

        featured.statsDetailRunID = screenshotStatsDetailRun(from: preparedRuns)?.id
        if featured.statsDetailRunID == nil, let synthetic = makeSyntheticRun(
            from: preparedRuns.first(where: { ($0.workoutType ?? .surf) == .dWParawing }) ?? preparedRuns.max(by: { $0.totalDistance < $1.totalDistance }),
            preferredDate: screenshotDate(year: year, month: 4, day: 1, hour: 15, minute: 21),
            workoutType: .dWParawing,
            locationString: preferredRoutePlaces(from: valueCounts(from: preparedRuns.compactMap(\.locationString))).first ?? "Cortaillod -> Yverdon-les-Bains",
            tags: ["#720s", "#82ml", "#screenshots"],
            minimumDistance: 26_600,
            minimumTopSpeed: 35,
            minimumAverageSpeed: 19.2
        ) {
            preparedRuns.append(synthetic)
            featured.statsDetailRunID = synthetic.id
        }

        featured.exportRunID = screenshotExportRun(from: preparedRuns)?.id ?? featured.statsDetailRunID

        preparedRuns = ensureStatisticsCoverage(for: preparedRuns, referenceYear: year)
        preparedRuns.sort { ($0.startLocation?.timestamp ?? $0.locations.first?.timestamp ?? .distantPast) > ($1.startLocation?.timestamp ?? $1.locations.first?.timestamp ?? .distantPast) }

        let tagCounts = valueCounts(from: preparedRuns.flatMap(\.tags))
        let placeCounts = valueCounts(from: preparedRuns.compactMap(\.locationString))
        let highlightedTags = screenshotHighlightedTags(from: tagCounts)
        let highlightedPlaces = preferredRoutePlaces(from: placeCounts)

        featured.homeRunID = featured.statsDetailRunID ?? preparedRuns.first?.id
        featured.mapRunID = featured.exportRunID ?? featured.statsDetailRunID ?? preparedRuns.first?.id
        featured.tagsRunID = screenshotTagsRun(from: preparedRuns, tagCounts: tagCounts, preferredTags: highlightedTags)?.id ?? featured.homeRunID
        featured.placesRunID = screenshotPlacesRun(from: preparedRuns, placeCounts: placeCounts, preferredPlaces: highlightedPlaces)?.id ?? featured.homeRunID
        featured.highlightedTags = highlightedTags
        featured.highlightedPlaces = highlightedPlaces

        preparedRuns = preparedRuns.map { compactScreenshotRun($0, featured: featured) }

        let queuedImportRuns = makeQueuedImportRuns(from: preparedRuns)
        featured.queuedImportRunIDs = queuedImportRuns.map(\.id)

        let runEdits = preparedRuns.map { run in
            makeScreenshotRunEdit(
                for: run,
                existing: existingRunEdits[run.id],
                featured: featured,
                referenceYear: year
            )
        }

        return ScreenshotFakeDataBundle(
            sourceYear: year,
            exportedAt: .now,
            importRuns: preparedRuns,
            queuedImportRuns: queuedImportRuns,
            runEdits: runEdits,
            dashboards: dashboardSeed,
            widgetDashboardIds: widgetSeed,
            featured: featured
        )
    }

    private func normalizeScreenshotRun(_ run: ImportRun, index: Int, year: Int) -> ImportRun {
        let startDate = run.startLocation?.timestamp ?? run.locations.first?.timestamp ?? screenshotDate(year: year, month: 1, day: 1, hour: 9, minute: 0)
        let durationHours = max(run.runTime / 60, 0.1)

        let averageSpeed: Double
        if run.averageSpeed > 0 {
            averageSpeed = run.averageSpeed
        } else {
            averageSpeed = (run.totalDistance / 1000) / durationHours
        }

        let routeTopSpeed = run.locations.compactMap(\.speed).max().map { $0 * 3.6 } ?? 0
        let topSpeed: Double
        if run.topSpeed > 0 {
            topSpeed = run.topSpeed
        } else {
            topSpeed = max(routeTopSpeed, averageSpeed * 1.28)
        }

        let averageHeartRate: Double
        if run.averageHeartRate > 0 {
            averageHeartRate = run.averageHeartRate
        } else if !run.heartRates.isEmpty {
            averageHeartRate = run.heartRates.map(\.heartRate).reduce(0, +) / Double(run.heartRates.count)
        } else {
            averageHeartRate = 0
        }

        let workoutType = run.workoutType ?? (run.totalDistance > 18_000 ? .downwindSUPFoil : .windsurf)
        let locationString = (run.locationString?.isEmpty ?? true) ? fallbackLocationString(index: index) : run.locationString
        let tags = run.tags.isEmpty ? fallbackTags(for: run, index: index) : uniqueOrdered(run.tags)

        return ImportRun(
            id: run.id,
            runTime: run.runTime,
            topSpeed: topSpeed,
            averageSpeed: averageSpeed,
            totalDistance: run.totalDistance,
            startLocation: run.startLocation ?? run.locations.first ?? LocationData(timestamp: startDate, latitude: 46.999, longitude: 6.952, altitude: 0, speed: nil, verticalAccuracy: 5),
            locations: run.locations,
            heartRates: run.heartRates,
            averageHeartRate: averageHeartRate,
            workoutType: workoutType,
            tags: tags,
            locationString: locationString
        )
    }

    private func ensureStatisticsCoverage(for runs: [ImportRun], referenceYear: Int) -> [ImportRun] {
        var coveredRuns = runs
        let calendar = Calendar.current
        let uniqueMonths = Set(coveredRuns.compactMap { run in
            let start = run.startLocation?.timestamp ?? run.locations.first?.timestamp
            return start.map { calendar.component(.month, from: $0) }
        })
        let uniqueYears = Set(coveredRuns.compactMap { run in
            let start = run.startLocation?.timestamp ?? run.locations.first?.timestamp
            return start.map { calendar.component(.year, from: $0) }
        })

        if uniqueMonths.count < 4 {
            let seedRuns = coveredRuns.isEmpty ? [] : coveredRuns.sorted {
                ($0.startLocation?.timestamp ?? $0.locations.first?.timestamp ?? .distantPast) > ($1.startLocation?.timestamp ?? $1.locations.first?.timestamp ?? .distantPast)
            }
            let targetDates = [
                screenshotDate(year: referenceYear, month: 1, day: 28, hour: 15, minute: 10),
                screenshotDate(year: referenceYear, month: 3, day: 7, hour: 11, minute: 29),
                screenshotDate(year: referenceYear, month: 4, day: 1, hour: 11, minute: 22),
                screenshotDate(year: referenceYear, month: 9, day: 12, hour: 14, minute: 18)
            ]

            for (offset, targetDate) in targetDates.enumerated() {
                let month = calendar.component(.month, from: targetDate)
                if uniqueMonths.contains(month) {
                    continue
                }
                if let clone = makeSyntheticRun(
                    from: seedRuns.indices.contains(offset) ? seedRuns[offset] : seedRuns.first,
                    preferredDate: targetDate,
                    workoutType: seedRuns.indices.contains(offset) ? seedRuns[offset].workoutType : seedRuns.first?.workoutType,
                    locationString: fallbackLocationString(index: coveredRuns.count + offset),
                    tags: seedRuns.indices.contains(offset) ? fallbackTags(for: seedRuns[offset], index: offset) : ["#screenshots"],
                    minimumDistance: nil
                ) {
                    coveredRuns.append(clone)
                }
            }
        }

        if uniqueYears.count < 2, let base = coveredRuns.max(by: { $0.totalDistance < $1.totalDistance }) {
            if let previousYearClone = makeSyntheticRun(
                from: base,
                preferredDate: screenshotDate(year: referenceYear - 1, month: 11, day: 19, hour: 12, minute: 47),
                workoutType: .downwindSUPFoil,
                locationString: "Saint-Aubin-Sauges -> St-Blaise",
                tags: ["#770R", "#foil", "#screenshots"],
                minimumDistance: 23_930,
                minimumTopSpeed: 31
            ) {
                coveredRuns.append(previousYearClone)
            }
        }

        return coveredRuns
    }

    private func makeSyntheticRun(
        from source: ImportRun?,
        preferredDate: Date,
        workoutType: WorkoutType?,
        locationString: String,
        tags: [String],
        minimumDistance: Double?,
        minimumTopSpeed: Double? = nil,
        minimumAverageSpeed: Double? = nil
    ) -> ImportRun? {
        guard let source else { return nil }

        let sourceStart = source.startLocation?.timestamp ?? source.locations.first?.timestamp ?? preferredDate
        let timeShift = preferredDate.timeIntervalSince(sourceStart)
        let speedBump = minimumTopSpeed.map { max(1.0, $0 / max(source.topSpeed, 1)) } ?? 1.0
        let totalDistance = max(source.totalDistance, minimumDistance ?? source.totalDistance)
        let averageSpeed = max(source.averageSpeed, minimumAverageSpeed ?? source.averageSpeed)
        let runTime = if averageSpeed > 0 {
            (totalDistance / 1000) / averageSpeed * 60
        } else {
            source.runTime
        }
        let shiftedLocations = source.locations.enumerated().map { index, location in
            var shifted = location
            shifted.timestamp = location.timestamp.addingTimeInterval(timeShift)
            shifted.speed = max((location.speed ?? 0) * speedBump, location.speed ?? 0)
            shifted.latitude += Double(index) * 0.0000015
            shifted.longitude -= Double(index) * 0.0000012
            return shifted
        }

        return ImportRun(
            id: UUID(),
            runTime: max(source.runTime, runTime),
            topSpeed: max(source.topSpeed, minimumTopSpeed ?? source.topSpeed),
            averageSpeed: averageSpeed,
            totalDistance: totalDistance,
            startLocation: shiftedLocations.first,
            locations: shiftedLocations,
            heartRates: source.heartRates.map {
                HeartRate(date: $0.date.addingTimeInterval(timeShift), heartRate: $0.heartRate)
            },
            averageHeartRate: source.averageHeartRate,
            workoutType: workoutType ?? source.workoutType,
            tags: uniqueOrdered(tags + source.tags),
            locationString: locationString
        )
    }

    private func makeQueuedImportRuns(from runs: [ImportRun]) -> [ImportRun] {
        Array(runs.prefix(2)).enumerated().map { index, run in
            ImportRun(
                id: UUID(),
                runTime: run.runTime,
                topSpeed: run.topSpeed,
                averageSpeed: run.averageSpeed,
                totalDistance: run.totalDistance,
                startLocation: run.startLocation,
                locations: run.locations,
                heartRates: [],
                averageHeartRate: 0,
                workoutType: nil,
                tags: [],
                locationString: run.locationString ?? fallbackLocationString(index: index)
            )
        }
    }

    private func makeScreenshotRunEdit(
        for run: ImportRun,
        existing: RunEdit?,
        featured: ScreenshotFeaturedRuns,
        referenceYear: Int
    ) -> RunEdit {
        let fallback = RunEdit(
            id: run.id,
            startLocation: run.startLocation,
            finishLocation: run.locations.last,
            deletedLocations: nil,
            newTotalTime: run.runTime,
            newTotalDistance: run.totalDistance,
            newTopSpeed: run.topSpeed,
            topSpeed10s: max(run.averageSpeed + 1.5, run.topSpeed - 4.2),
            topSpeed1s: max(run.topSpeed + 1.4, run.averageSpeed + 2.2),
            newAverageSpeed: run.averageSpeed,
            popUps: (run.workoutType ?? .surf).calculateFoilingStats ? max(Int(run.totalDistance / 4100), 3) : nil,
            percentageOnFoil: (run.workoutType ?? .surf).calculateFoilingStats ? min(96, max(61, run.averageSpeed * 4.1)) : nil,
            turnsCount: (run.workoutType ?? .surf).countTurns ? max(Int(run.totalDistance / 42), 6) : nil,
            longestDistanceOnFoil: (run.workoutType ?? .surf).calculateFoilingStats ? max(run.totalDistance * 0.42, 680) : nil,
            waves: nil,
            newTags: uniqueOrdered(run.tags),
            newWorkoutType: run.workoutType ?? .surf,
            locationString: run.locationString ?? fallbackLocationString(index: referenceYear),
            angles: featured.angleRunID == run.id ? screenshotAngles(from: run.locations) : nil
        )

        guard var existing else {
            return fallback
        }

        existing.startLocation = existing.startLocation ?? fallback.startLocation
        existing.finishLocation = existing.finishLocation ?? fallback.finishLocation
        existing.newTotalTime = existing.newTotalTime ?? fallback.newTotalTime
        existing.newTotalDistance = existing.newTotalDistance ?? fallback.newTotalDistance
        existing.newTopSpeed = existing.newTopSpeed ?? fallback.newTopSpeed
        existing.topSpeed10s = existing.topSpeed10s ?? fallback.topSpeed10s
        existing.topSpeed1s = existing.topSpeed1s ?? fallback.topSpeed1s
        existing.newAverageSpeed = existing.newAverageSpeed ?? fallback.newAverageSpeed
        existing.popUps = existing.popUps ?? fallback.popUps
        existing.percentageOnFoil = existing.percentageOnFoil ?? fallback.percentageOnFoil
        existing.turnsCount = existing.turnsCount ?? fallback.turnsCount
        existing.longestDistanceOnFoil = existing.longestDistanceOnFoil ?? fallback.longestDistanceOnFoil
        existing.waves = existing.waves ?? fallback.waves
        existing.newTags = uniqueOrdered((existing.newTags ?? []) + (fallback.newTags ?? []))
        existing.newWorkoutType = existing.newWorkoutType ?? fallback.newWorkoutType
        existing.locationString = existing.locationString ?? fallback.locationString
        existing.angles = (existing.angles?.isEmpty == false) ? existing.angles : fallback.angles
        return existing
    }

    private func screenshotAngles(from locations: [LocationData]) -> [MapAngle]? {
        guard locations.count > 300 else { return nil }

        return [
            MapAngle(coordinates: [
                CLLocationCoordinate2D(latitude: locations[50].latitude, longitude: locations[50].longitude),
                CLLocationCoordinate2D(latitude: locations[115].latitude, longitude: locations[115].longitude),
                CLLocationCoordinate2D(latitude: locations[180].latitude, longitude: locations[180].longitude)
            ]),
            MapAngle(coordinates: [
                CLLocationCoordinate2D(latitude: locations[155].latitude, longitude: locations[155].longitude),
                CLLocationCoordinate2D(latitude: locations[230].latitude, longitude: locations[230].longitude),
                CLLocationCoordinate2D(latitude: locations[295].latitude, longitude: locations[295].longitude)
            ])
        ]
    }

    private func fallbackLocationString(index: Int) -> String {
        let locations = [
            "Concise -> St-Blaise",
            "Neuenburg -> St-Blaise",
            "Saint-Aubin-Sauges",
            "Saint-Aubin-Sauges -> St-Blaise",
            "Cortaillod -> Yverdon-les-Bains",
            "Hyeres"
        ]
        return locations[index % locations.count]
    }

    private func fallbackTags(for run: ImportRun, index: Int) -> [String] {
        let baseTags = switch run.workoutType ?? .surf {
        case .downwindSUPFoil: ["#foil", "#dw", "#850S"]
        case .downwindSUP: ["#dw", "#paddle", "#screenshots"]
        case .parawing: ["#parawing", "#screenshots", "#lightwind"]
        case .paraUpDown: ["#udw", "#parawing", "#screenshots"]
        case .windsurf: ["#mistral", "#angle", "#screenshots"]
        case .windFoil: ["#foil", "#windfoil", "#screenshots"]
        default: ["#screenshots", "#session", "#water"]
        }
        let rotation = ["#sunrise", "#foil", "#speed", "#gear", "#wind", "#lake"]
        return uniqueOrdered(baseTags + [rotation[index % rotation.count]])
    }

    private func screenshotDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }

    private func uniqueOrdered<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }

    private func valueCounts(from values: [String]) -> [String: Int] {
        values.reduce(into: [String: Int]()) { partialResult, value in
            partialResult[value, default: 0] += 1
        }
    }

    private func sortedScreenshotValues(from counts: [String: Int]) -> [String] {
        counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs, default: 0]
            let rhsCount = counts[rhs, default: 0]
            if lhsCount == rhsCount {
                return lhs < rhs
            }
            return lhsCount > rhsCount
        }
    }

    private func screenshotAngleRun(from runs: [ImportRun]) -> ImportRun? {
        let preferredTypes: [WorkoutType] = [.parawing, .dWParawing, .paraUpDown, .windsurf, .windFoil, .wingFoil]
        for preferredType in preferredTypes {
            let matches = runs.filter { ($0.workoutType ?? .surf) == preferredType }
            if let best = matches.max(by: { angleRunScore(for: $0) < angleRunScore(for: $1) }) {
                return best
            }
        }

        return runs
            .filter { ($0.workoutType ?? .surf).angleSport }
            .max(by: { angleRunScore(for: $0) < angleRunScore(for: $1) })
    }

    private func screenshotParawingRun(from runs: [ImportRun]) -> ImportRun? {
        runs
            .filter { ($0.workoutType ?? .surf) == .parawing }
            .max(by: { angleRunScore(for: $0) < angleRunScore(for: $1) })
    }

    private func screenshotStatsDetailRun(from runs: [ImportRun]) -> ImportRun? {
        let preferred = runs
            .filter {
                ($0.workoutType ?? .surf) == .dWParawing &&
                $0.totalDistance >= 20_000 &&
                $0.averageSpeed >= 19 &&
                $0.tags.contains(where: { $0.caseInsensitiveCompare("#720s") == .orderedSame })
            }
            .max(by: { statsDetailScore(for: $0) < statsDetailScore(for: $1) })

        if let preferred {
            return preferred
        }

        let downwindParawing = runs
            .filter { ($0.workoutType ?? .surf) == .dWParawing && $0.totalDistance >= 20_000 }
            .max(by: { statsDetailScore(for: $0) < statsDetailScore(for: $1) })

        if let downwindParawing {
            return downwindParawing
        }

        return runs
            .filter { ($0.workoutType ?? .surf).isDWSport && $0.totalDistance >= 20_000 }
            .max(by: { statsDetailScore(for: $0) < statsDetailScore(for: $1) })
    }

    private func screenshotExportRun(from runs: [ImportRun]) -> ImportRun? {
        runs
            .filter { ($0.workoutType ?? .surf).isDWSport }
            .max(by: { exportRunScore(for: $0) < exportRunScore(for: $1) })
    }

    private func screenshotTagsRun(from runs: [ImportRun], tagCounts: [String: Int], preferredTags: [String]) -> ImportRun? {
        if let preferredTag = preferredTags.first {
            let matches = runs.filter { run in
                run.tags.contains(where: { $0.caseInsensitiveCompare(preferredTag) == .orderedSame })
            }
            if let best = matches.max(by: { tagScore(for: $0, tagCounts: tagCounts) < tagScore(for: $1, tagCounts: tagCounts) }) {
                return best
            }
        }

        return runs
            .filter { !$0.tags.isEmpty }
            .max { lhs, rhs in
                tagScore(for: lhs, tagCounts: tagCounts) < tagScore(for: rhs, tagCounts: tagCounts)
            }
    }

    private func screenshotPlacesRun(from runs: [ImportRun], placeCounts: [String: Int], preferredPlaces: [String]) -> ImportRun? {
        for preferredPlace in preferredPlaces {
            let matches = runs.filter { $0.locationString == preferredPlace }
            if let best = matches.max(by: { placeScore(for: $0, placeCounts: placeCounts) < placeScore(for: $1, placeCounts: placeCounts) }) {
                return best
            }
        }

        return runs
            .filter { !($0.locationString?.isEmpty ?? true) }
            .max { lhs, rhs in
                placeScore(for: lhs, placeCounts: placeCounts) < placeScore(for: rhs, placeCounts: placeCounts)
            }
    }

    private func screenshotHighlightedTags(from counts: [String: Int]) -> [String] {
        let sortedTags = sortedScreenshotValues(from: counts)
        let preferredOrder = ["#850S", "#720s", "#82ml", "#1300S", "#980S", "#1130S", "#105dw", "#65ML"]
        for preferred in preferredOrder {
            if let match = sortedTags.first(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
                return [match]
            }
        }
        return Array(sortedTags.prefix(1))
    }

    private func preferredRoutePlaces(from counts: [String: Int]) -> [String] {
        let routeCounts = counts.filter { key, _ in
            key.contains("→") || key.contains("->")
        }
        let routePlaces = sortedScreenshotValues(from: routeCounts)
        if !routePlaces.isEmpty {
            return Array(routePlaces.prefix(2))
        }
        return Array(sortedScreenshotValues(from: counts).prefix(2))
    }

    private func tagScore(for run: ImportRun, tagCounts: [String: Int]) -> Int {
        run.tags.reduce(0) { partialResult, tag in
            partialResult + tagCounts[tag, default: 0]
        }
    }

    private func placeScore(for run: ImportRun, placeCounts: [String: Int]) -> Int {
        guard let place = run.locationString else { return 0 }
        return placeCounts[place, default: 0]
    }

    private func angleRunScore(for run: ImportRun) -> Double {
        let typeBonus: Double
        switch run.workoutType ?? .surf {
        case .parawing: typeBonus = 180
        case .dWParawing: typeBonus = 150
        case .paraUpDown: typeBonus = 120
        case .windsurf: typeBonus = 90
        default: typeBonus = 0
        }

        let angleTagBonus = run.tags.contains(where: { $0.localizedCaseInsensitiveContains("720") || $0.localizedCaseInsensitiveContains("angle") }) ? 45.0 : 0.0
        return typeBonus + angleTagBonus + run.averageSpeed + (run.totalDistance / 1000)
    }

    private func statsDetailScore(for run: ImportRun) -> Double {
        let heartRateBonus = run.heartRates.isEmpty ? 0.0 : 40.0
        let tagBonus = run.tags.contains(where: { $0.caseInsensitiveCompare("#720s") == .orderedSame }) ? 60.0 : 0.0
        let typeBonus = (run.workoutType ?? .surf) == .dWParawing ? 100.0 : 0.0
        let speedScore = run.averageSpeed * 8
        let distanceScore = run.totalDistance / 1000
        return typeBonus + tagBonus + heartRateBonus + speedScore + distanceScore
    }

    private func exportRunScore(for run: ImportRun) -> Double {
        let heartRateBonus = run.heartRates.isEmpty ? 0.0 : 25.0
        return heartRateBonus + run.averageSpeed * 6 + (run.totalDistance / 1000)
    }

    private func compactScreenshotRun(_ run: ImportRun, featured: ScreenshotFeaturedRuns) -> ImportRun {
        let featuredIDs = Set([
            featured.angleRunID,
            featured.exportRunID,
            featured.tagsRunID,
            featured.placesRunID,
            featured.statsDetailRunID,
            featured.parawingRunID,
            featured.upDownwindParawingRunID,
            featured.mapRunID,
            featured.homeRunID
        ].compactMap { $0 })

        let isAngleRun = featured.angleRunID == run.id
        let isFeaturedRun = featuredIDs.contains(run.id)
        let maxLocations = isAngleRun ? 420 : (isFeaturedRun ? 320 : 180)
        let maxHeartRates = isFeaturedRun ? 48 : 20

        return ImportRun(
            id: run.id,
            runTime: run.runTime,
            topSpeed: run.topSpeed,
            averageSpeed: run.averageSpeed,
            totalDistance: run.totalDistance,
            startLocation: run.startLocation,
            locations: downsampled(run.locations, maxCount: maxLocations),
            heartRates: downsampled(run.heartRates, maxCount: maxHeartRates),
            averageHeartRate: run.averageHeartRate,
            workoutType: run.workoutType,
            tags: uniqueOrdered(run.tags),
            locationString: run.locationString
        )
    }

    private func downsampled<T>(_ values: [T], maxCount: Int) -> [T] {
        guard values.count > maxCount, maxCount > 1 else { return values }

        let lastIndex = values.count - 1
        let interiorCount = max(0, maxCount - 2)
        var sampledIndices = [0]

        if interiorCount > 0 {
            for step in 1...interiorCount {
                let progress = Double(step) / Double(interiorCount + 1)
                let index = Int(round(progress * Double(lastIndex)))
                if index > 0 && index < lastIndex {
                    sampledIndices.append(index)
                }
            }
        }

        sampledIndices.append(lastIndex)
        sampledIndices = uniqueOrdered(sampledIndices).sorted()
        return sampledIndices.map { values[$0] }
    }

    private func screenshotFallbackDashboards(referenceYear: Int) -> [Dashboard] {
        let updated = screenshotDate(year: referenceYear, month: 1, day: 28, hour: 14, minute: 41)
        let bielerseeURL = "https://wind.example/bielersee"
        let neuchatelURL = "https://wind.example/neuchatel"

        func trackedElement(url: String, label: String, value: String) -> TrackedElement {
            TrackedElement(url: url, xpath: "//value", userLabel: label, lastValue: value, lastUpdated: updated, lastError: nil)
        }

        return [
            Dashboard(
                name: "Bielersee",
                elements: [
                    trackedElement(url: bielerseeURL, label: "Wingreis Avg", value: "1.7 kn"),
                    trackedElement(url: bielerseeURL, label: "Wingreis Gust", value: "3.3 kn"),
                    trackedElement(url: bielerseeURL, label: "Wingreis Dir", value: "O"),
                    trackedElement(url: bielerseeURL, label: "Vingelz Avg", value: "1.0 kn"),
                    trackedElement(url: bielerseeURL, label: "Vingelz Gust", value: "2.2 kn"),
                    trackedElement(url: bielerseeURL, label: "Vingelz Dir", value: "SSW")
                ]
            ),
            Dashboard(
                name: "Lac de Neuchatel",
                elements: [
                    trackedElement(url: neuchatelURL, label: "Yverdon Avg", value: "4.3 kn"),
                    trackedElement(url: neuchatelURL, label: "Yverdon Gust", value: "7.0 kn"),
                    trackedElement(url: neuchatelURL, label: "Yverdon Dir", value: "ENE"),
                    trackedElement(url: neuchatelURL, label: "Concise Avg", value: "12.0 kn"),
                    trackedElement(url: neuchatelURL, label: "Concise Gust", value: "13.0 kn"),
                    trackedElement(url: neuchatelURL, label: "Concise Dir", value: "NE")
                ]
            )
        ]
    }

    private func loadWorkoutsFromHealthKit(year: Int) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let calendar = Calendar.current
            let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
            let startOfNextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? .distantFuture

            let workoutTypePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .paddleSports),
                HKQuery.predicateForWorkouts(with: .sailing),
                HKQuery.predicateForWorkouts(with: .surfingSports)
            ])
            let datePredicate = HKQuery.predicateForSamples(withStart: startOfYear, end: startOfNextYear)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutTypePredicate, datePredicate])
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: HKQuantityType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func makeImportRunFromHealthWorkout(_ workout: HKWorkout) async throws -> ImportRun? {
        guard let route = await workoutRoute(for: workout) else {
            return nil
        }

        let locations = await locationData(from: route)
        guard locations.count > 1 else {
            return nil
        }

        let heartRates = try await heartRates(for: workout)
        let averageHeartRate = if heartRates.isEmpty {
            await averageHeartRate(for: workout) ?? 0
        } else {
            heartRates.map(\.heartRate).reduce(0, +) / Double(heartRates.count)
        }

        let backup = backupWorkoutData.first(where: { $0.startDate == workout.startDate })
        let metadata = getWorkoutMetadata(workout: workout, backup: backup)
        let runEdit = runEdits.first(where: { $0.id == workout.uuid })

        let totalDistance = metadata.totalDistance > 0
            ? metadata.totalDistance
            : calculatedDistance(from: locations)
        let durationMinutes = workout.duration / 60
        let averageSpeed = metadata.averageSpeed > 0
            ? metadata.averageSpeed
            : (durationMinutes > 0 ? (totalDistance / 1000) / (durationMinutes / 60) : 0)
        let topSpeed = metadata.topSpeed > 0
            ? metadata.topSpeed
            : locations.compactMap(\.speed).max().map { $0 * 3.6 } ?? 0

        return ImportRun(
            id: workout.uuid,
            runTime: durationMinutes,
            topSpeed: topSpeed,
            averageSpeed: averageSpeed,
            totalDistance: totalDistance,
            startLocation: metadata.startLocation ?? locations.first,
            locations: locations,
            heartRates: heartRates,
            averageHeartRate: averageHeartRate,
            workoutType: runEdit?.newWorkoutType ?? metadata.workoutType,
            tags: runEdit?.newTags ?? metadata.tags,
            locationString: runEdit?.locationString
        )
    }

    private func workoutRoute(for workout: HKWorkout) async -> HKWorkoutRoute? {
        await withCheckedContinuation { continuation in
            loadWorkoutRoute(workout: workout) { route in
                continuation.resume(returning: route)
            }
        }
    }

    private func locationData(from route: HKWorkoutRoute) async -> [LocationData] {
        await withCheckedContinuation { continuation in
            locationDataFromWorkoutRoute(route: route) { locations in
                continuation.resume(returning: locations)
            }
        }
    }

    private func averageHeartRate(for workout: HKWorkout) async -> Double? {
        await withCheckedContinuation { continuation in
            getAVGHeartRate(for: workout) { averageHeartRate in
                continuation.resume(returning: averageHeartRate)
            }
        }
    }

    private func heartRates(for workout: HKWorkout) async throws -> [HeartRate] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictEndDate
            )
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let result = (samples as? [HKQuantitySample] ?? []).map { sample in
                    HeartRate(
                        date: sample.startDate,
                        heartRate: sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                    )
                }
                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func calculatedDistance(from locations: [LocationData]) -> Double {
        guard locations.count > 1 else { return 0 }

        return zip(locations, locations.dropFirst()).reduce(0) { partial, pair in
            let first = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let second = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partial + first.distance(from: second)
        }
    }
    
    /// imports a run to the imported runs
    func importRun(run: ImportRun) {
        importedRuns.append(run)
        saveImportedRunsToDisk()
        
        // find if another run is already at that time and remove that one
        let matchingRuns = self.runStatistics.filter { self.doTimeRangesOverlap(start1: $0.startDate, end1: $0.endDate, start2: run.locations.first?.timestamp, end2: run.locations.last?.timestamp) }
        DispatchQueue.main.async {
            self.runStatistics.removeAll { statisticRun in
                matchingRuns.contains(where: { $0.id == statisticRun.id })
            }
        }
                
        var newStatistic = RunStatistic(id: run.id, runName: "", crewStatistics: [], runTime: run.runTime, runDistance: run.totalDistance, topSpeed: run.topSpeed, averageSpeed: run.averageSpeed, kCalories: 0, locationData: run.locations, tags: run.tags, workoutType: run.workoutType ?? .surf, startDate: run.locations.first?.timestamp ?? Date(), endDate: run.locations.last?.timestamp ?? Date(), topSpeed1s: 0, topSpeed10s: 0, popUps: 0, percentageOnFoil: 0, turnsCount: 0)
        newStatistic.startLocation = run.startLocation
        newStatistic.locationString = run.locationString
        
        DispatchQueue.main.async {
            self.runStatistics.append(newStatistic)
        }
        
        let updatedTags = self.updateMetaData(statistics: self.runStatistics)
        
        // sort the array, find matching statistics update the grouped array
        DispatchQueue.main.async {
            self.tags = updatedTags
            
            self.saveTags()
            
            self.runStatistics.sort(by: { $0.startDate ?? $0.locationData.first?.timestamp ?? Date.distantPast > $1.startDate ?? $1.locationData.first?.timestamp ?? Date.distantPast})

            
            // Free user only show 7 runs
            if !self.hasPurchasedPremium {
                self.statisticsCount = self.runStatistics.count
                if self.statisticsCount > 5 {
                    self.runStatistics = Array(self.runStatistics.prefix(5))
                }
            }
            
            self.updateGroupedRunArray()
            
            self.loadingRunStatistics = false
            
            self.updateLocationStrings()
            
        }
    }
    
    
    
    func parseGPX(from url: URL, completion: @escaping (ImportRun?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource.")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                let decoder = XMLDecoder()

                // Configure date decoding
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    } else {
                        let fallbackFormatter = ISO8601DateFormatter()
                        fallbackFormatter.formatOptions = [.withInternetDateTime]
                        if let date = fallbackFormatter.date(from: dateString) {
                            return date
                        }
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
                    }
                }

                let gpx = try decoder.decode(GPX.self, from: data)

                guard let track = gpx.trk.first, let trackSegment = track.trkseg.first else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                var locations: [LocationData] = []
                var heartRates: [HeartRate] = []
                var totalDistance: Double = 0
                var topSpeed: Double = 0
                var totalHeartRate: Double = 0
                var validHeartRateCount: Double = 0
                var startTime: Date? = nil
                var endTime: Date? = nil

                for (index, point) in trackSegment.trkpt.enumerated() {
                    guard let latitude = Double(point.lat), let longitude = Double(point.lon), let time = point.time else {
                        continue
                    }

                    let locationData = LocationData(timestamp: time, latitude: latitude, longitude: longitude, altitude: Double(point.ele ?? ""), speed: point.speed)
                    locations.append(locationData)

                    if let hr = point.extensions?.trackPointExtension?.hr, let hrValue = Double(hr) {
                        heartRates.append(HeartRate(date: time, heartRate: hrValue))
                        totalHeartRate += hrValue
                        validHeartRateCount += 1
                    }

                    if let speed = point.speed, speed > topSpeed {
                        topSpeed = speed
                    }

                    if startTime == nil {
                        startTime = time
                    }
                    endTime = time

                    if index > 0 {
                        let prevPoint = trackSegment.trkpt[index - 1]
                        totalDistance += calculateDirectDistance(
                            from: Member(name: "lastLocation", latitude: Double(prevPoint.lat)!, longitude: Double(prevPoint.lon)!),
                            to: Member(name: "now", latitude: latitude, longitude: longitude)
                        ) ?? 0
                    }
                }

                guard let startTimeUnwrapped = startTime, let endTimeUnwrapped = endTime else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let timeInterval = endTimeUnwrapped.timeIntervalSince(startTimeUnwrapped)
                let runTimeMinutes = timeInterval / 60
                let averageSpeed: Double = runTimeMinutes > 0 ? (totalDistance / (runTimeMinutes / 60)) / 1000 : 0
                let averageHeartRate = validHeartRateCount > 0 ? totalHeartRate / validHeartRateCount : 0
                let topSpeedKmh = topSpeed * 3.6
                
                self.createLocationNames(statisticsData: RunStatistic(id: UUID(), locationData: locations, startLocation: locations.first)) { location in
                    let run = ImportRun(
                        id: UUID(),
                        runTime: runTimeMinutes,
                        topSpeed: topSpeedKmh,
                        averageSpeed: averageSpeed,
                        totalDistance: totalDistance,
                        startLocation: locations.first,
                        locations: locations,
                        heartRates: heartRates,
                        averageHeartRate: averageHeartRate,
                        locationString: location
                    )
                    
                    DispatchQueue.main.async {
                        completion(run)
                    }
                }
                                
                } catch {
                    print("Error parsing GPX: \(error)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
        }
    }
    
    // MARK: - Error Logging
    var errorLog: String = "Errors will show up here.\n"
    private let errorFileName = "error_log.txt"
    
    private var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(errorFileName)
    }
    
    func loadErrorLog() {
        do {
            errorLog = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            errorLog = "Errors will show up here.\n"
            print("Could not load error log: \(error)")
        }
    }
    
    private func logError(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let newEntry = "[\(timestamp)] \(message)\n"
        errorLog += newEntry
        print("Error: \(message)")
        saveErrorLog()
    }
    
    private func saveErrorLog() {
        do {
            try errorLog.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Could not save error log: \(error)")
        }
    }
    
    func clearLog() {
        errorLog = "Errors will show up here.\n"
        saveErrorLog()
    }
    
    func getErrorLog() -> String {
            return errorLog
        }
    
    // Get error log as array of individual entries for list display
    func getErrorEntries() -> [String] {
        return errorLog.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    #endif
}
