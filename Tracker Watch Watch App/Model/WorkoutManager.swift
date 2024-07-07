//
//  WorkoutManager.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import Foundation
import HealthKit
import SwiftUI

class WorkoutManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @AppStorage("workoutType") var workoutType: WorkoutType = .downwindSUPFoil
            
    @Published var showingSummaryView: Bool = false {
        didSet {
            // Sheet dismissed
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    // navigation path
    @Published var path = NavigationPath()
    
    // init
    override init() {
        super.init()
        setupLocationManager()
        loadTagsFromWorkouts()
    }
    
    // MARK: - Tags
    
    @AppStorage("statisticTags") private var tagsData: Data = Data()
    
    var statisticTags: [String] {
        get {
            if let decodedTags = try? JSONDecoder().decode([String].self, from: tagsData) {
                return decodedTags
            } else {
                return []
            }
        }
        set {
            if let encodedTags = try? JSONEncoder().encode(newValue) {
                tagsData = encodedTags
            }
        }
    }
    
    @Published var activeTags = [String]()
    
    private func loadTagsFromWorkouts() {
        self.loadWorkoutsFromHealthKit { workouts in
            
            var tags = [String]()
            
            for workout in workouts {
                let tagsString = workout.metadata?[Constants.customMetadataKeyTags] as? String ?? ""
                let newTags = tagsString.split(separator: " ").map { String($0) }
                
                for tag in newTags {
                    if !tag.isEmpty {
                        if !tags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                            tags.append(tag)
                        }
                    }
                }
            }
            
            tags = tags.sorted()
            
            DispatchQueue.main.async {
                self.statisticTags = tags
            }
        }
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

    // MARK: - Locations and Workout
    @Published var withGPS = true
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.activityType = .fitness
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    var routeBuilder: HKWorkoutRouteBuilder?
    
    let currentWatch = WKInterfaceDevice.current()
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType.activityType
        configuration.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            return
        }
        
        builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        
        session?.delegate = self
        builder?.delegate = self
        
        // Start the workout session and begin data collection.
        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { (success, error) in
            // The workout has started.
        }
        // start rout builder if gps should be active
        if withGPS {
            routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
        }
        startLocationService()
        
        currentWatch.enableWaterLock()
        currentWatch.play(.start)
    }
    
    // Request authorization to access HealthKit and to access location
    func requestAuthorization() {
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            //            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            //            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKSeriesType.workoutRoute(),
            HKObjectType.activitySummaryType()
        ]
        
        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error.
        }
        // access to location
        locationManager?.requestWhenInUseAuthorization()
    }
    
    private var locationManager: CLLocationManager?
    var isUpdatingLocation = false
    
    private var ignoreFirstFewLocations = true
    private let secondsWeIgnoreLocations = 5.0
    private var locationManagerStartTime = Date.distantPast
    
    // Kalman Filter
    var resetKalmanFilter: Bool = false
    var kalmanFilter: HCKalmanAlgorithm?
    @Published var rValue = 1.0
    @Published var sigma = 0.6
    
    
    // Location Authorization
    private var locationAuthorization = false
    private var comingFromStartLocation = false
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            // Permission granted, start location updates
            locationAuthorization = true
            if comingFromStartLocation {
                startLocationService()
            }
        } else if status == .notDetermined {
            // Location access not determined, request permission
            locationManager?.requestWhenInUseAuthorization()
        } else {
            // Handle denied or restricted permission
            locationAuthorization = false
            locationManager?.requestWhenInUseAuthorization()
        }
        comingFromStartLocation = false
    }
    
    /// checks and starts location service
    private func startLocationService() {
        if self.locationAuthorization {
            if !isUpdatingLocation {
                print("Starting location tracking")
                self.locationManager?.startUpdatingLocation()
                self.locationManager?.startUpdatingHeading()
                locationManagerStartTime = Date.now
                isUpdatingLocation = true
            }
        } else {
            // show location authorization request again
            comingFromStartLocation = true
            self.locationManager?.requestWhenInUseAuthorization()
        }
    }
    
    private var startLocation: CLLocation?
    
    /// stops the location service and resets the ignore var
    private func stopLocationService() {
        print("Stopping location tracking")
        self.locationManager?.stopUpdatingLocation()
        self.locationManager?.stopUpdatingHeading()
        ignoreFirstFewLocations = true
        resetKalmanFilter = true
        isUpdatingLocation = false
        
        // reset locations
        DispatchQueue.main.async {
            self.userLocation = nil
            self.previousUserLocation = nil
        }
    }
    
    /// the location manager function
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // ignoring the locations for a few seconds
        if ignoreFirstFewLocations {
            
            if locationManagerStartTime.addingTimeInterval(secondsWeIgnoreLocations) < Date.now || locations.last!.horizontalAccuracy < 5.1 {
                ignoreFirstFewLocations = false
            }
            
        } else {
            
            if !withGPS {
                startLocation = locations.last
                stopLocationService()
            }
            
            guard let newLocation = locations.last else {
                print("Something wrong with locationManager")
                return }
            
            if kalmanFilter == nil {
                // setting the rValue of the Kalman filter. Higher values will give higher roundness to trajectories.
                self.kalmanFilter?.rValue = rValue
                self.kalmanFilter?.sigma = sigma
                
                // initializing the kalman filter
                self.kalmanFilter = HCKalmanAlgorithm(initialLocation: newLocation)
                
                let startLocation = CLLocation(
                    coordinate: newLocation.coordinate,
                    altitude: newLocation.altitude,
                    horizontalAccuracy: newLocation.horizontalAccuracy,
                    verticalAccuracy: newLocation.verticalAccuracy,
                    course: newLocation.course,
                    speed: newLocation.speed,
                    timestamp: newLocation.timestamp
                )
                
                if newLocation.horizontalAccuracy <= Constants.minHorizontalAccuracy {
                    routeBuilder?.insertRouteData([startLocation]) { (success, error) in
                        if !success {
                            // Handle any errors here.
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.previousUserLocation = self.userLocation
                        self.userLocation = newLocation
                        self.updateStatistic()
                    }
                }
            } else {
                if let kalmanFilter = self.kalmanFilter {
                    if resetKalmanFilter == true {
                        
                        // two of these four are not needed, but save is save
                        self.kalmanFilter?.rValue = rValue
                        self.kalmanFilter?.sigma = sigma
                        kalmanFilter.rValue = rValue
                        kalmanFilter.sigma = sigma
                        
                        kalmanFilter.resetKalman(newStartLocation: newLocation)
                        
                        resetKalmanFilter = false
                        
                    } else {
                        
                        var kalmanLocation = kalmanFilter.processState(currentLocation: newLocation)
                        kalmanLocation = CLLocation(
                            coordinate: kalmanLocation.coordinate,
                            altitude: kalmanLocation.altitude,
                            horizontalAccuracy: kalmanLocation.horizontalAccuracy,
                            verticalAccuracy: kalmanLocation.verticalAccuracy,
                            course: kalmanLocation.course,
                            speed: newLocation.speed,
                            timestamp: kalmanLocation.timestamp
                        )
                        
                        if newLocation.horizontalAccuracy <= Constants.minHorizontalAccuracy {
                            routeBuilder?.insertRouteData([kalmanLocation]) { (success, error) in
                                if !success {
                                    // Handle any errors here.
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.previousUserLocation = self.userLocation
                                self.userLocation = kalmanLocation
                                self.updateStatistic()
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Updates the run statistic
    private func updateStatistic() {
        // adding up the distance if there is any data
        if let previousUserLocation = previousUserLocation {
            let addedDistance = userLocation?.distance(from: previousUserLocation) ?? 0.0
            distance += addedDistance
        }
        // updating the top speed
        if (userLocation?.speed ?? 0.0) > topSpeed {
            topSpeed = (userLocation?.speed)!
        }
        // updating average speed
        if let elapsedTime = builder?.elapsedTime, elapsedTime != 0 {
            averageSpeed = distance / elapsedTime
        } else {
            averageSpeed = 0
        }
    }
    
    // MARK: - State Control
    
    // The workout session state.
    @Published var running = false
    
    func pause() {
        session?.pause()
        if withGPS {
            stopLocationService()
        }
    }
    
    func resume() {
        session?.resume()
        if withGPS {
            startLocationService()
        }
    }
    
    func togglePause() {
        if running == true {
            pause()
        } else {
            resume()
        }
    }
    
    func endWorkout() {
        session?.end()
        showingSummaryView = true
        path = NavigationPath()
        currentWatch.play(.stop)
    }
    
    // MARK: - Workout Metrics
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    /// workout distance in meter
    @Published var distance: Double = 0
    /// workout top speed in m/s
    @Published var topSpeed: Double = 0
    /// workout avarage speed in m/s
    @Published var averageSpeed: Double = 0
    /// current location
    @Published var userLocation: CLLocation?
    /// previous location
    var previousUserLocation: CLLocation?
    
    @Published var workout: HKWorkout?
    
    /// making average pace string
    func makeAveragePaceString() -> String {
        let totalTime = builder?.elapsedTime ?? 0
        let pace = totalTime / (distance / 1000)
        let prettyPace = makePrettyMinutesString(timeInSeconds: pace, paceFormat: true)
        if prettyPace != "" {
            return prettyPace
        } else {
            return "--'--\""
        }
    }
    
    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }

        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
            default:
                return
            }
        }
    }
    
    func resetWorkout() {
        builder = nil
        session = nil
        workout = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
        distance = 0
        topSpeed = 0
        averageSpeed = 0
        userLocation = nil
        previousUserLocation = nil
        activeTags = []
    }

}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            self.running = toState == .running
        }
        print("workoutSession func was triggered. State is now: \(toState)")
        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            if withGPS {
                // stop location tracking
                stopLocationService()
            }
            
            let runDistance = HKQuantity(unit: .meter(), doubleValue: distance)
            let runTopSpeed = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: topSpeed)
            let runAverageSpeed = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: averageSpeed)
            let tags = activeTags.joined(separator: " ")
            let workoutType = workoutType

            var allMetadata: [String: Any] = [
                Constants.customMetadataKeyWorkoutType: workoutType.rawValue,
                Constants.customMetadataKeyTags: tags
            ]
            if distance != 0.0 {
                allMetadata[Constants.customTotalDistanceKey] = runDistance
            }
            if topSpeed != 0.0 {
                allMetadata[HKMetadataKeyMaximumSpeed] = runTopSpeed
            }
            if averageSpeed != 0.0 {
                allMetadata[HKMetadataKeyAverageSpeed] = runAverageSpeed
            }
            if !withGPS {
                if let startLocation = startLocation {
                    let locationString = "\(startLocation.coordinate.latitude), \(startLocation.coordinate.longitude)"
                    allMetadata[Constants.customLocationKey] = locationString
                }
            }
            
            builder?.addMetadata(allMetadata, completion: { success, error in
                if let error = error {
                    print("Error adding metadata: \(error.localizedDescription)")
                }
                self.builder?.endCollection(withEnd: date) { (success, error) in
                    self.builder?.finishWorkout { (workout, error) in
                        DispatchQueue.main.async {
                            self.workout = workout
                        }
                        if self.withGPS {
                            if let workout = workout {
                                self.routeBuilder?.finishRoute(with: workout, metadata: nil) { newRoute, error in
                                    if let error = error {
                                        print("Error finishing route: \(error.localizedDescription)")
                                    }
                                    
                                    if newRoute == nil {
                                        print("Failed to finish route.")
                                    }
                                    
                                    // Optional: Do something with the route here
                                    print("Successfully saved workout and route to HealthKit.")
                                    
                                    // Discard the routeBuilder and workoutBuilder
                                    self.routeBuilder = nil
                                    self.builder = nil
                                }
                            }
                        }
                    }
                }
            })
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }

            let statistics = workoutBuilder.statistics(for: quantityType)

            // Update the published values.
            updateForStatistics(statistics)
        }
    }
}
