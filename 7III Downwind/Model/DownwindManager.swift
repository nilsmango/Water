//
//  DownwindManager.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI
import KeychainSwift
import CoreLocation
import _MapKit_SwiftUI
import HealthKit


class DownwindManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - App Storage and Init
    @AppStorage("runListSorting") var runListSorting: RunListSorting = .distanceAscending
    @AppStorage("showListDetail") var showListDetail: Bool = true
    @AppStorage("measurementSystem") var measurementSystem: MeasurementSystem = .metric
    @AppStorage("workoutType") var workoutType: WorkoutType = .downwindSUPFoil
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Statistics
    @Published var activeStatistics: Bool = false
    @Published var runStatistics: [RunStatistic] = []
    @Published var groupedRunStatistics: [[[RunStatistic]]] = []
    @Published var tags = [String]()
    // TODO: make this non published
    @Published var locationAccuracy: Double = 1000.0
    var currentRunStatisticIndex = 0
    var routeBuilder: HKWorkoutRouteBuilder? = nil
    var workoutBuilder: HKWorkoutBuilder? = nil
    
    /// Activates the run statistic
    func startStatistic(onlyStatistics: Bool, tags: [String] = []) {
        // Safety first
        if !activeStatistics {
            activeStatistics = true
            // start location tracking if we have not done that
            if onlyStatistics {
                checkAndStartLocationService(cloudService: false)
            }
            // create a new RunStatistic and record the first point to the runStatistic
            // map the member names
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
            var newStatistic: RunStatistic
            if user.latitude != nil && user.longitude != nil {
                newStatistic = RunStatistic(id: UUID(), runName: activeRun.name, crewStatistics: crewStatistics, runTime: 0.0, runDistance: 0.0, topSpeed: user.speed ?? 0.0, locationData: [LocationData(timestamp: Date.now, latitude: user.latitude!, longitude: user.longitude!, speed: user.speed ?? 0.0)], tags: tags)
            } else {
                newStatistic = RunStatistic(id: UUID(), runName: activeRun.name, crewStatistics: crewStatistics, runTime: 0.0, runDistance: 0.0, topSpeed: user.speed ?? 0.0, locationData: [], tags: tags)
            }
            
            newStatistic.workoutType = workoutType
            newStatistic.startDate = Date()
            runStatistics.append(newStatistic)
            currentRunStatisticIndex = runStatistics.endIndex - 1
            
            if HKHealthStore.isHealthDataAvailable() {
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = newStatistic.workoutType?.activityType ?? .surfingSports
                configuration.locationType = .outdoor
                
                workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
                workoutBuilder?.beginCollection(withStart: Date(), completion: { _, _ in
                    // starting
                })
                
                routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            }
        }
    }
    
    /// Stops the current run statistic
    func stopStatistic(onlyStatistic: Bool = false) {
        // Safety first
        if activeStatistics {
            // record one last point to the runStatistic
            updateStatistic()
            // deactivate statistic recording
            activeStatistics = false
            // save endDate
            runStatistics[currentRunStatisticIndex].endDate = Date()
            
            if onlyStatistic {
                // Stop location update
                stopLocationService()
            }
            
            // saving the workout
            if HKHealthStore.isHealthDataAvailable() {
                saveHealthWorkout()
            } else {
                // save the statistics to disk if we don't have health available
                saveRunStatistics()
            }
        }
    }
    
    let customMetadataKeyWorkoutType = "7III Workout Type"
    let customMetadataKeyTags = "Tags"
    let customTotalDistanceKey = "Total Distance"
    
    private func saveHealthWorkout() {
        let activeRunStatistic = runStatistics[currentRunStatisticIndex]
        
        let runDistance = HKQuantity(unit: .meter(), doubleValue: activeRunStatistic.runDistance)
        let topSpeed = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: activeRunStatistic.topSpeed / 3.6)
        let averageSpeed = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: (activeRunStatistic.averageSpeed ?? 0) / 3.6)
        let tags = activeRunStatistic.tags?.joined(separator: " ") ?? ""
        let workoutType = activeRunStatistic.workoutType ?? .surfingSport
        
        let allMetadata: [String: Any] = [
            customMetadataKeyWorkoutType: workoutType.rawValue,
            customMetadataKeyTags: tags,
            customTotalDistanceKey: runDistance,
            HKMetadataKeyMaximumSpeed: topSpeed,
            HKMetadataKeyAverageSpeed: averageSpeed
        ]
       
        
        workoutBuilder?.addMetadata(allMetadata, completion: { success, error in
            if let error = error {
                print("Error adding metadata: \(error.localizedDescription)")
                return
            }
            
            guard success else {
                print("Failed to add metadata.")
                return
            }
            
            
            self.workoutBuilder?.endCollection(withEnd: Date(), completion: { success, error in
                if let error = error {
                    print("Error ending collection: \(error.localizedDescription)")
                    return
                }
                
                guard success else {
                    print("Failed to end collection.")
                    return
                }
                
                self.workoutBuilder?.finishWorkout(completion: { workout, error in
                    if let error = error {
                        print("Error finishing workout: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let myWorkout = workout else {
                        print("Failed to finish workout.")
                        return
                    }
                    
                    // TODO: add crew statistic as own metada here!
                    self.routeBuilder?.finishRoute(with: myWorkout, metadata: nil) { newRoute, error in
                        if let error = error {
                            print("Error finishing route: \(error.localizedDescription)")
                            return
                        }
                        
                        guard newRoute != nil else {
                            print("Failed to finish route.")
                            return
                        }
                        
                        // Optional: Do something with the route here
                        print("Successfully saved workout and route to HealthKit.")
                        
                        // Add the new statistic to the grouped array
                        let newStatistic = self.runStatistics[self.currentRunStatisticIndex]
                        DispatchQueue.main.async {
                            if self.groupedRunStatistics.isEmpty {
                                self.groupedRunStatistics.append([[newStatistic]])
                            } else if self.groupedRunStatistics[0].isEmpty {
                                self.groupedRunStatistics[0].append([newStatistic])
                            } else {
                                self.groupedRunStatistics[0][0].insert(newStatistic, at: 0)
                            }
                        }
                        // Discard the routeBuilder and workoutBuilder
                        self.routeBuilder = nil
                        self.workoutBuilder = nil
                        
                    }
                })
            })
        })
    }
    
    /// Updates the run statistic
    private func updateStatistic() {
        if activeStatistics {
            
            // only count if we have some accuracy
            if locationAccuracy <= 16.0 {

            // only update if we have valid data
                if user.latitude != nil && user.longitude != nil {
                    
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
                        let addedDistance = calculateDirectDistance(from: Member(name: "lastLocation", latitude: lastLatitude, longitude: lastLongitude), to: user) ?? 0.0
                        
                        runStatistics[currentRunStatisticIndex].runDistance += addedDistance
                    }
                    
                    // updating the top speed
                    if user.speed ?? 0.0 > currentStatistic.topSpeed {
                        runStatistics[currentRunStatisticIndex].topSpeed = user.speed!
                    }
                    
                    // updating the data
                    let newData = LocationData(timestamp: Date.now, latitude: user.latitude!, longitude: user.longitude!, speed: user.speed ?? 0.0)
                    runStatistics[currentRunStatisticIndex].locationData.append(newData)
                }
            }
        }
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
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        } catch {
            fatalError("Can't find documents directory.")
        }
    }
    
    func calculateSessions(for index: Int) -> Int {
        var totalSessions = 0
        if groupedRunStatistics.count > index {
            for runs in groupedRunStatistics[index] {
                for (index, run) in runs.enumerated() {
                    // if startDate is in between start and endDate of last run, don't count the run as a own session
                    if index > 0 {
                        if runs[index-1].startDate! < run.endDate! {
                            // don't count
                        } else {
                            totalSessions += 1
                        }
                    } else {
                        totalSessions += 1
                    }
                }
//                totalSessions += runs.count
                
            }
        }
        return totalSessions
    }
    
    
    // File name of the statistics data
    private let fileName = "locationStatistics.data"
    
    
    /// Save runStatistics to disk
    func saveRunStatistics() {
            DispatchQueue.global(qos: .background).async {
                do {
                    let data = try JSONEncoder().encode(self.runStatistics)
                    let url = try self.getDocumentsDirectory().appendingPathComponent(self.fileName)
                    try data.write(to: url)
                } catch {
                    print("Error saving runStatistics: \(error)")
                }
            }
    }
    
    
    func deleteWorkout(id: UUID) {
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
                                        print("Successfully deleted workout from health.")
                                        
                                        // also remove it from the arrays
                                        if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                                            DispatchQueue.main.async {
                                                self.runStatistics.remove(at: runIndex)
                                            }
                                        forOuter: for i in 0..<self.groupedRunStatistics.count {
                                                for j in 0..<self.groupedRunStatistics[i].count {
                                                    if let index = self.groupedRunStatistics[i][j].firstIndex(where: { $0.id == id }) {
                                                        DispatchQueue.main.async {
                                                            self.groupedRunStatistics[i][j].remove(at: index)
                                                        }
                                                        break forOuter
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                
            } else {
                print("No workout found with the specified UUID. Saving the array to disk")
                // if can't find in health
                self.saveRunStatistics()
            }
            
            
        }
        
        healthStore.execute(workoutQuery)
    }
    
//    func saveEditedRoute(statistic: RunStatistic) {
//        
//        let workoutPredicate = HKQuery.predicateForObject(with: statistic.id)
//        
//        // Create a query to fetch the workout
//        let workoutQuery = HKSampleQuery(sampleType: .workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
//            guard error == nil else {
//                // Handle error
//                print("Error fetching workout: \(error!.localizedDescription)")
//                return
//            }
//            
//            if let workout = samples?.first as? HKWorkout {
//                
//                // remove workout
//                self.healthStore.delete(workout) { (success, error) in
//                                    if let error = error {
//                                        print("Error deleting workout: \(error.localizedDescription)")
//                                        return
//                                    }
//                                    
//                                    if success {
//                                        // Create and save a new workout with the updated route and parameters
//                                        self.addWorkout(from: statistic, oldWorkout: workout)
//                                    }
//                                }
//                
//            } else {
//                print("No workout found with the specified UUID. Saving the array to disk")
//                // if can't find in health
//                self.saveRunStatistics()
//            }
//            
//            
//        }
//        
//        healthStore.execute(workoutQuery)
//        
//    }
    
//    // Function to update the workout with the new route and parameters
//    private func addWorkout(from statistic: RunStatistic, oldWorkout: HKWorkout) {
//        // TODO: total distance,startTime, endTime, totalTime, max, average speed, totalDistance, route, tags, kcal, heart rate fucking everything
//        
//            // TODO: Prepare the new route data (do it really, not this crap) and other parameters to update
//            let newRoute = statistic.locationData.map { location in
//                HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
//            }
//            
//            // Example for updating other parameters (e.g., metadata)
//            let metadata: [String: Any] = [
//                // metadata
//            ]
//            
//            // Create a new workout builder to save the updated data
//            let configuration = HKWorkoutConfiguration()
//            configuration.activityType = statistic.workoutType?.activityType ?? .surfingSports
//            configuration.locationType = .outdoor
//            
//            workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: oldWorkout.device ?? nil)
//            
//            // Add metadata to the workout builder
//            workoutBuilder.addMetadata(metadata)
//            
//            // Add the new route data
//            for route in newRoute {
//                workoutBuilder.add([route], completion: { (success, error) in
//                    if let error = error {
//                        print("Error adding route to workout: \(error.localizedDescription)")
//                    }
//                })
//            }
//            
//            // Finish the workout
//            workoutBuilder.finishWorkout { (workout, error) in
//                if let error = error {
//                    print("Error finishing workout: \(error.localizedDescription)")
//                } else {
//                    print("Workout updated successfully")
//                }
//            }
//        }
    
    /// Load runStatistics from disk
    func loadRunStatistics() {
        DispatchQueue.global(qos: .background).async {
            self.loadWorkoutsFromHealthKit { workouts in
                do {
                    let url = try self.getDocumentsDirectory().appendingPathComponent(self.fileName)
                    let data = try Data(contentsOf: url)
                    var decodedStatistics = try JSONDecoder().decode([RunStatistic].self, from: data)
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
                    
                    // Update the statistic from health
                    if HKHealthStore.isHealthDataAvailable() {
                        print("workout number: \(workouts.count)")
                        for workout in workouts {
                            let metaData = self.getWorkoutMetadata(workout: workout)
                            if let runIndex = self.runStatistics.firstIndex(where: { $0.id == workout.uuid }) {
                                DispatchQueue.main.async {
                                    self.runStatistics[runIndex].runTime = workout.duration / 60
                                    self.runStatistics[runIndex].runDistance = metaData.totalDistance
                                    self.runStatistics[runIndex].topSpeed = metaData.topSpeed
                                    self.runStatistics[runIndex].averageSpeed = metaData.averageSpeed
                                    self.runStatistics[runIndex].kCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                                    self.runStatistics[runIndex].tags = metaData.tags
                                    self.runStatistics[runIndex].workoutType = metaData.workoutType
                                    self.runStatistics[runIndex].startDate = workout.startDate
                                    self.runStatistics[runIndex].endDate = workout.endDate
                                }
                            } else {
                                let statistic = RunStatistic(id: workout.uuid, runName: "", crewStatistics: [], runTime: workout.duration / 60, runDistance: metaData.totalDistance, topSpeed: metaData.topSpeed, averageSpeed: metaData.averageSpeed, kCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0, locationData: [], tags: metaData.tags, workoutType: metaData.workoutType, startDate: workout.startDate, endDate: workout.endDate)
                                
                                DispatchQueue.main.async {
                                    self.runStatistics.append(statistic)
                                }
                            }
                        }
                        // sort the array, update the grouped array
                        DispatchQueue.main.async {
                            self.runStatistics.sort(by: { $0.startDate ?? $0.locationData.first?.timestamp ?? Date.distantPast > $1.startDate ?? $1.locationData.first?.timestamp ?? Date.distantPast})
                            self.updateGroupedRunArray()
                        }
                    }
                    
                    print("updating tags")
                    let tags = self.updateMetaData(statistics: self.runStatistics)
                    
                    DispatchQueue.main.async {
                        // Update UI on the main thread
                        self.tags = tags
                    }
                } catch {
                    print("Error loading runStatistics: \(error)")
                }
            }
        }
    }
        
    private func getWorkoutMetadata(workout: HKWorkout) -> (tags: [String], workoutType: WorkoutType, averageSpeed: Double, topSpeed: Double, totalDistance: Double) {
        let rawWorkoutType = workout.metadata?[customMetadataKeyWorkoutType] as? String ?? ""
            let tagsString = workout.metadata?[customMetadataKeyTags] as? String ?? ""
            let tags = tagsString.split(separator: " ").map { String($0) }
            
            let workoutType = WorkoutType(rawValue: rawWorkoutType) ?? .surfingSport
        
        let topSpeed: Double
        if let maxSpeedQuantity = workout.metadata?[HKMetadataKeyMaximumSpeed] as? HKQuantity {
            // Assuming the unit is meters per second (m/s), convert it to kilometers per hour (km/h)
            topSpeed = maxSpeedQuantity.doubleValue(for: .meter().unitDivided(by: .second())) * 3.6
        } else {
            topSpeed = 0
        }
        
        let averageSpeed: Double
        if let averageSpeedQuantity = workout.metadata?[HKMetadataKeyAverageSpeed] as? HKQuantity {
            // Assuming the unit is meters per second (m/s), convert it to kilometers per hour (km/h)
            averageSpeed = averageSpeedQuantity.doubleValue(for: .meter().unitDivided(by: .second())) * 3.6
        } else {
            averageSpeed = 0
        }
        
        let totalDistance: Double
        if let distanceQuantity = workout.metadata?[customTotalDistanceKey] as? HKQuantity {
            // Assuming the unit is meters per second (m/s), convert it to kilometers per hour (km/h)
            totalDistance = distanceQuantity.doubleValue(for: .meter())
        } else {
            totalDistance = 0
        }
        
        
            
        return (tags: tags, workoutType: workoutType, averageSpeed: averageSpeed, topSpeed: topSpeed, totalDistance: totalDistance)
        }
    
    private func updateGroupedRunArray() {
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

            groupedRunStatistics = grouped
        }
    
    private func loadWorkoutsFromHealthKit(completion: @escaping ([HKWorkout]) -> Void) {
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .paddleSports),
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
    
    func loadRouteAndHeartFromHealth(statistic: RunStatistic, completion: @escaping (Bool) -> Void) {
        let id = statistic.id
        // also add the workout route
        self.loadWorkoutRouteHeartFromHealth(id: id) { route, averageHeartRate in
            if let route = route {
                self.locationDataFromWorkoutRoute(route: route) { locationData in
                    // TODO: calculate run time, distance and top speed from locationData (if it is nil or zero)
                    if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                        DispatchQueue.main.async {
                            self.runStatistics[runIndex].locationData = locationData
                        }
                    } else {
                        let run = RunStatistic(id: id, runName: "", crewStatistics: [], runTime: 0.0, runDistance: 0.0, topSpeed: 0.0, locationData: locationData)
                        DispatchQueue.main.async {
                            self.runStatistics.append(run)
                        }
                    }
                }
            }
            if let averageHeartRate = averageHeartRate {
                if let runIndex = self.runStatistics.firstIndex(where: { $0.id == id }) {
                    DispatchQueue.main.async {
                        self.runStatistics[runIndex].averageHeartRate = averageHeartRate
                    }
                }
            }
            completion(true)
        }
        completion(false)
    }
    
    private func loadWorkoutRouteHeartFromHealth(id: UUID, completion: @escaping (HKWorkoutRoute?, Double?) -> Void) {
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
                    
                self.getAVGHeartRate(for: workout) { averageHeartRate in
                    completion(route, averageHeartRate)
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
            print("workout route samples found:")
            print(samples?.count ?? "nil")
            // Process the initial route data here.
            guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
//                print("Error fetching workout route: \(String(describing: error))")
                completion(nil)
                return
            }
            completion(route)
            
        }

//        routeQuery.updateHandler = { (query, samples, deleted, anchor, error) in
//            
//            guard error == nil else {
//                // Handle any errors here.
//                fatalError("The update failed.")
//            }
//            
//            // Process updates or additions here.
//        }


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
                    print("Error: \(error!.localizedDescription)")
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
    
    func fetchHeartRatesOverTime(startTime: Date?, endTime: Date?, completion: @escaping ([Date: (Double, Double)]?, Error?) -> Void) {
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
        let timeInterval = intervalDuration / Double(samplesCount)

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

                    heartRateData[statistics.startDate] = (minHeartRate, maxHeartRate)
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
                print("Error: \(error)")
                return
            }
            
            guard let locations = locationsOrNil else {
                fatalError("*** Invalid State: This can only fail if there was an error. ***")
            }
            
            print("getting locations: \(locations.count)")
            // Do something with this batch of location data.
            for location in locations {
                let locationData = LocationData(timestamp: location.timestamp, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, speed: location.speed)
                allLocations.append(locationData)
            }
            
            if done {
                // The query returned all the location data associated with the route.
                // Do something with the complete data set.
                print("sent locations")
                completion(allLocations)
            }
            
            // You can stop the query by calling:
            // store.stop(query)
            
        }
        healthStore.execute(query)
    }

//    private func mergeWorkoutsWithStatistics(_ workouts: [HKWorkout], statistics: [RunStatistic]) -> [RunStatistic] {
//        var mergedStatistics = statistics
//        print("running merge")
//        for workout in workouts {
//            self.loadWorkoutRouteFromHealth(workout: workout) { route in
//                self.locationDataFromWorkoutRoute(route: route) { allLocations in
//                    let runStatistic = RunStatistic(from: workout, locationData: allLocations)
//                    print("got runstatistc with \(allLocations.count)")
//                if let index = mergedStatistics.firstIndex(where: { $0.id == runStatistic.id }) {
//                    mergedStatistics[index].merge(with: runStatistic)
//                } else {
//                    mergedStatistics.append(runStatistic)
//                    
//                }
//                }
//            }
//        }
//
//        return mergedStatistics
//    }
    
    
    /// save statistic to disk with new tags
    func saveStatisticWithNewTags(tags: [String], statisticsData: RunStatistic) {
        if let index = runStatistics.firstIndex(where: { $0.id == statisticsData.id }) {
            runStatistics[index].tags = tags
            saveRunStatistics()
            
            // adding tags to tags
            for tag in tags {
                if !tags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                    self.tags.append(tag)
                }
            }
            self.tags = self.tags.sorted()
        }
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
    
    /// filter the statistics array
    func filterStatistics(tags: [String]) -> [RunStatistic] {
        if tags.isEmpty {
            return runStatistics
        } else {
            let filteredStatistics = runStatistics.filter { statistic in
                tags.allSatisfy { tag in
                    if let statisticTags = statistic.tags {
                        let tagString = statisticTags.joined(separator: " ").lowercased()
                        return tagString.contains(tag.lowercased())
                    } else {
                        return false
                    }
                }
            }
            
            return filteredStatistics
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
            let locationString = "LocationData(timestamp: Date().addingTimeInterval(-\(secondsAgoStarted - secondsToAddToDate)), latitude: \(location.latitude), longitude: \(location.longitude), speed: \(location.speed ?? 0.0)), "
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
    
    private func makePrettyMinutesString(timeInSeconds: Double, paceFormat: Bool = false) -> String {
        if !timeInSeconds.isNaN && timeInSeconds != .infinity && timeInSeconds != -.infinity {
            let roundedTime = timeInSeconds.rounded()
            let minutes = Int(roundedTime / 60.0)
            let seconds = Int(roundedTime) % 60
            let timeInMinutesString = String(minutes)
            let additionToSeconds: String
            if seconds > 9 {
                additionToSeconds = ""
            } else {
                additionToSeconds = "0"
            }
            let dividers = paceFormat ? ("'", "\"") : (":", "")
            
            let prettyTime = timeInMinutesString + dividers.0 + additionToSeconds + String(seconds) + dividers.1
            
            return prettyTime
        } else {
            return ""
        }
        
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
        
        print("new poly lines: \(newPolyLineNumber)")
        return newPolyLineNumber
        
    }
    
    /// creates polyline coordinates and colors
    func createPolylineData(locationData: [LocationData], numberOfElementsToKeep: Int, coordinatesCount: Int) async -> [PolylineData] {
        guard numberOfElementsToKeep > 0 else {
            return []
        }
        // create an array of all the location pairs
        var locationPairs = [(LocationData, LocationData)]()
        
        let stepSize = Double(coordinatesCount) / Double(numberOfElementsToKeep)
        
        
        for i in 0..<numberOfElementsToKeep - 1 {
            let index = Int(round(Double(i) * stepSize))
            let index2 = Int(round(Double(i + 1) * stepSize))
            // Ensure the index is within bounds of the array
            if index != index2 && index2 < coordinatesCount {
                locationPairs.append((locationData[index], locationData[index2]))
            }
        }
       
        // create an array for all the speeds of the location pairs
        func calculateSpeedsOfLocationPairs(locationPair: (LocationData, LocationData)) -> Double {
            let distance = calculateDirectDistance(from: Member(name: "from", latitude: locationPair.0.latitude, longitude: locationPair.0.longitude), to: Member(name: "to", latitude: locationPair.1.latitude, longitude: locationPair.1.longitude)) ?? 0.0
            let time = locationPair.1.timestamp.timeIntervalSince(locationPair.0.timestamp)
            let speed = distance / time
            return speed
        }
        
        let locationSpeeds = locationPairs.map { calculateSpeedsOfLocationPairs(locationPair: $0) }
        let maxSpeed = locationSpeeds.max() ?? 1.0
        let quantizedSpeeds = locationSpeeds.map { $0 / maxSpeed }
        
        func createColorFromQuantizedSpeed(speed: Double) -> Color {
            let hue = 0.33 * speed
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
        }
        
        let lineColors = quantizedSpeeds.map { createColorFromQuantizedSpeed(speed: $0)}
        
        // create the polyline data
        var polylineData = [PolylineData]()
        
        for (index, line) in locationPairs.enumerated() {
            let polyline = PolylineData(coordinates: [CLLocationCoordinate2D(latitude: line.0.latitude, longitude: line.0.longitude), CLLocationCoordinate2D(latitude: line.1.latitude, longitude: line.1.longitude)], strokeColor: lineColors[index])
            polylineData.append(polyline)
        }
        print("drawing polylines: \(polylineData.count)")
        return polylineData
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
        
        return (totalDistance, topSpeed)
    }
    
    
    /// set a new start point for a run statistic
    func setStart(for statistic: RunStatistic, coordinate: CLLocationCoordinate2D) async -> RunStatistic {
        // remove all points before the start
        if let startIndex = statistic.locationData.firstIndex(where: { $0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude }) {

            let newLocationData = Array(statistic.locationData[startIndex..<statistic.locationData.endIndex])
            
            // recalculate distance, max speed, etc.
            let startTime = newLocationData.first!.timestamp
            let finishTime = newLocationData.last!.timestamp
            let newRunTime = timeInMinutesFromDates(startDate: startTime, finishDate: finishTime)
            let distanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newLocationData)
            let newRunDistance = distanceAndSpeed.totalDistance
            let newTopSpeed = distanceAndSpeed.topSpeed
            
            // editing the statistic
            var newStatistic = statistic
            newStatistic.runTime = newRunTime
            newStatistic.runDistance = newRunDistance
            newStatistic.topSpeed = newTopSpeed
            newStatistic.locationData = newLocationData
            newStatistic.startDate = startTime
            newStatistic.endDate = finishTime
            
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
            let startTime = newLocationData.first!.timestamp
            let finishTime = newLocationData.last!.timestamp
            let newRunTime = timeInMinutesFromDates(startDate: startTime, finishDate: finishTime)
            let distanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newLocationData)
            let newRunDistance = distanceAndSpeed.totalDistance
            let newTopSpeed = distanceAndSpeed.topSpeed
            
            var newStatistic = statistic
            newStatistic.runTime = newRunTime
            newStatistic.runDistance = newRunDistance
            newStatistic.topSpeed = newTopSpeed
            newStatistic.locationData = newLocationData
            newStatistic.startDate = startTime
            newStatistic.endDate = finishTime
            
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
            let startTime = newLocationData.first!.timestamp
            let finishTime = newLocationData.last!.timestamp
            let newRunTime = timeInMinutesFromDates(startDate: startTime, finishDate: finishTime)
            let distanceAndSpeed = calculateTotalDistanceAndTopSpeed(locations: newLocationData)
            let newRunDistance = distanceAndSpeed.totalDistance
            let newTopSpeed = distanceAndSpeed.topSpeed
            
            var newStatistic = statistic
            newStatistic.runTime = newRunTime
            newStatistic.runDistance = newRunDistance
            newStatistic.topSpeed = newTopSpeed
            newStatistic.locationData = newLocationData
            newStatistic.startDate = startTime
            newStatistic.endDate = finishTime
            
            return newStatistic
            
        } else {
            return statistic
        }
    }
    
    // MARK: - Health
    
    let healthStore = HKHealthStore()
    
    func requestHealthAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute()
        ]
        
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
        }
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
            self.user.onlyWatching = false
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
            self.user.onlyWatching = false
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
            self.user.onlyWatching = true
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
        
        DispatchQueue.main.async {
            
            // start active run
            self.activeRun.id = run.id
            self.activeRun.name = run.name
            self.activeRun.startedOn = run.startedOn
            self.activeRun.active = true
            
            // check if we have authorization to see location and start location
            self.checkAndStartLocationService()
        }
        
    }
    
    /// load run as watching only run
    private func startWatchingRun(run: Run) async throws {
        
        DispatchQueue.main.async {
            
            // start active run
            self.activeRun.id = run.id
            self.activeRun.name = run.name
            self.activeRun.startedOn = run.startedOn
            self.activeRun.active = true
            
            // start download timer
            self.startUploadDownloadTimer(onlyDownload: true)
        }
        
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
        
        // set location of user to nil
        self.user.latitude = nil
        self.user.longitude = nil
        self.user.speed = nil
    }
    
    /// checks and starts location service
    private func checkAndStartLocationService(cloudService: Bool = true) {
        if self.locationAuthorization {
            // TODO: check if location is enabled?
            // check if location is enabled
            //                        if CLLocationManager.locationServicesEnabled() {
            // starting the location and heading updating + timer for upload and download
            print("Starting location tracking")
            self.locationManager?.startUpdatingLocation()
            self.locationManager?.startUpdatingHeading()
            locationManagerStartTime = Date.now
            
            if cloudService {
                // starting the upload/download timer
                self.startUploadDownloadTimer()
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
    func uploadUserLocation() async throws {
        print("uploading user")
        let url = try createDWURL(endpoint: Endpoints.members)
        
        let userToUpdate = self.user
        
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
            // Stop statistics if they are on
            self.stopStatistic()
            
            // stop timer
            self.runTimer?.invalidate()
            self.runTimer = nil
            
            // stop location and header updating
            self.stopLocationService()
            
            // set location of user to nil
            self.user.latitude = nil
            self.user.longitude = nil
            self.user.speed = nil
            
            self.startUploadDownloadTimer(onlyDownload: true)
            
            
        }
    }
    
    /// quit active run: removes user from run, stops run timer, stops updating location, stops updating header, sets location, speed and heading to nil and updates the user in the DB to that
    func quitActiveRun() async throws {
        
        // reset the active run var
        DispatchQueue.main.async {
            // Stop statistics if they are on
            self.stopStatistic()
            
            // make run inactive, keeping the id
            self.activeRun = Run(name: "", members: self.activeRun.members, active: false)
            
            self.runTimer?.invalidate()
            self.runTimer = nil
            
            // stop location and header updating
            self.stopLocationService()
            
            
            
        }
        // remove user from run / delete run if user is last member
        do {
            try await removeUserFromRun(run: activeRun)
            // remove members from active run (probably not necessary)
            DispatchQueue.main.async {
                self.activeRun.members = []
            }
        } catch {
            print("Error removing user from run: \(error)")
        }
        
        // update the user location of nil on db for maximum privacy
        do {
            try await uploadUserLocation()
        } catch {
            print("Error uploading user location: \(error)")
        }
    }
    

    /// loading members of active run
    func loadRunMembers(notUpdatingMemberStatistic: Bool = true) async throws {
        print("loading members")
        guard let runID = activeRun.id else {
            print("Error: No active run ID!")
            return }
        
        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members)
        
        let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
        
        DispatchQueue.main.async {
            self.activeRun.members = membersResponse.filter { $0.id != self.user.id }
            if notUpdatingMemberStatistic == false {
                self.updateMemberStatistics()
            }
        }
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

    @Published var user: Member = Member(id: nil, name: "Your Name", status: "All good.")
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
    
    private var ignoreFirstFewLocations = true
    private let secondsWeIgnoreLocations = 5.0
    private var locationManagerStartTime = Date.distantPast
    
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
        
        // ignoring the locations for a few seconds
        if ignoreFirstFewLocations {
            
            if locationManagerStartTime.addingTimeInterval(secondsWeIgnoreLocations) < Date.now || locations.last!.horizontalAccuracy < 5.1 {
                ignoreFirstFewLocations = false
            }
            
        } else {
            
            guard let newLocation = locations.last else {
                print("Something wrong with locationManager")
                return }
            
            if collectRawGPS {
                routeBuilder?.insertRouteData(locations) { (success, error) in
                    if !success {
                        // Handle any errors here.
                    }
                }
                
                DispatchQueue.main.async {
                    self.user.latitude = newLocation.coordinate.latitude
                    self.user.longitude = newLocation.coordinate.longitude
                    var speed = newLocation.speed * 60 * 60 / 1000
                    if speed < 0.0 {
                        speed = 0.0
                    }
                    self.user.speed = speed
                    
                    self.locationAccuracy = newLocation.horizontalAccuracy
                    
                    self.updateStatistic()
                }
                
            } else {
                
                    if kalmanFilter == nil {
                        // setting the rValue of the Kalman filter. Higher values will give higher roundness to trajectories.
                        self.kalmanFilter?.rValue = rValue
                        self.kalmanFilter?.sigma = sigma
                        
                        // initializing the kalman filter
                        self.kalmanFilter = HCKalmanAlgorithm(initialLocation: newLocation)
                        
                        routeBuilder?.insertRouteData(locations) { (success, error) in
                            if !success {
                                // Handle any errors here.
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.user.latitude = newLocation.coordinate.latitude
                            self.user.longitude = newLocation.coordinate.longitude
                            var speed = newLocation.speed * 60 * 60 / 1000
                            if speed < 0.0 {
                                speed = 0.0
                            }
                            self.user.speed = speed
                            
                            self.locationAccuracy = newLocation.horizontalAccuracy
                            
                            self.updateStatistic()
                        }
                    }
                    else {
                        if let kalmanFilter = self.kalmanFilter {
                            if resetKalmanFilter == true {
                                
                                // two of these four are not needed, but save is save
                                self.kalmanFilter?.rValue = rValue
                                self.kalmanFilter?.sigma = sigma
                                kalmanFilter.rValue = rValue
                                kalmanFilter.sigma = sigma
                                
                                kalmanFilter.resetKalman(newStartLocation: newLocation)
                                
                                resetKalmanFilter = false
                                
                            }
                            else {
                                let kalmanLocation = kalmanFilter.processState(currentLocation: newLocation)
                                
                                routeBuilder?.insertRouteData([kalmanLocation]) { (success, error) in
                                    if !success {
                                        // Handle any errors here.
                                    }
                                }
                                
                                DispatchQueue.main.async {
                                    self.user.latitude = kalmanLocation.coordinate.latitude
                                    self.user.longitude = kalmanLocation.coordinate.longitude
                                    var speed = newLocation.speed * 60 * 60 / 1000
                                    if speed < 0.0 {
                                        speed = 0.0
                                    }
                                    self.user.speed = speed
                                    
                                    self.locationAccuracy = newLocation.horizontalAccuracy
                                    
                                    self.updateStatistic()
                                }
                            }
                        }
                    }
            }
            
            
        }
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
                        let newLocation = LocationData(timestamp: location.timestamp, latitude: kalmanLocation.coordinate.latitude, longitude: kalmanLocation.coordinate.longitude)
                                                
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
    
    
}
