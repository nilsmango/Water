//
//  WorkoutManager.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import Foundation
import HealthKit
import SwiftUI
import StoreKit

typealias Transaction = StoreKit.Transaction

public enum StoreError: Error {
    case failedVerification
}

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
        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()
        
        Task {
            // During store initialization, request products from the App Store.
            await loadProductIdentifiersAndRequestProducts()
            
            await updateCustomerProductStatus()
        }
        setupLocationManager()
        loadTagsFromWorkouts()
    }
    
    deinit {
        updateListenerTask?.cancel()
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
    
    func removeTag(_ tag: String) {
        statisticTags = statisticTags.filter { $0 != tag }
    }
    
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
    
    func incrementWorkoutCount(for type: WorkoutType) {
        workoutUsageCount[type, default: 0] += 1
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
                for tag in tags {
                    if !self.statisticTags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                        self.statisticTags.append(tag)
                    }
                }
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
        // update the workout usage count
        incrementWorkoutCount(for: workoutType)
        
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
        
        currentWatch.play(.start)
        
        // add tags to saved tags
        for tag in activeTags {
            if !statisticTags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                statisticTags.append(tag)
            }
        }
        
        WKExtension.shared().enableWaterLock()
    }
    
    // Request authorization to access HealthKit and to access location
    func requestAuthorization() {
        checkHealthKitAuthorizationStatus()
        // access to location
        locationManager?.requestWhenInUseAuthorization()
    }
    
    func requestHealthKitAuthorization() {        
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
            DispatchQueue.main.async {
                self.checkHealthKitAuthorizationStatus()
            }
        }
    }
    
    // The health kit quantity type to write to the health store.
    private let typesToShare: Set = [
        HKQuantityType.workoutType(),
        HKSeriesType.workoutRoute()
    ]
    
    @Published var hasHealthActivated = false
    
    func checkHealthKitAuthorizationStatus() {
        var hasNotAuthorized = false
        
        for type in typesToShare {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                hasNotAuthorized = true
                requestHealthKitAuthorization()
                break
            }
        }
        hasHealthActivated = !hasNotAuthorized
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
    
    // MARK: - In App Purchase
    
    @AppStorage("Premium") var hasPurchasedPremium = false
    @Published var purchasedProducts = [Product]()
    @Published var premiumProducts: [Product] = []
    @Published var subscriptionRenewalDate: Date? = nil
    @Published var nextBillingText = ""
    @Published var unableToLoadProducts = false
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
            // Request products from the App Store using the identifiers that the `product_ids.plist` file defines.
            let products = try await Product.products(for: productIdentifiers)
            DispatchQueue.main.async {
                self.premiumProducts = products
            }

        } catch {
            print("Failed product request from the App Store server. \(error)")
            DispatchQueue.main.async {
                self.unableToLoadProducts = true
            }
        }
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
