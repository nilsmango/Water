//
//  DownwindManager.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI
import KeychainSwift
import CoreLocation

class DownwindManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: App Storage
    @AppStorage("runListSorting") var runListSorting: RunListSorting = .distanceAscending
    @AppStorage("showListDetail") var showListDetail: Bool = true
    @AppStorage("measurementSystem") var measurementSystem: MeasurementSystem = .metric
    
    
    // MARK: Run
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
        try await addMembersToRun(members: [user], runID: newRun.id!)
        
        // updating the run name from the db
        let updatedRunName = try await getRunNameFromId(runId: newRun.id!)
        let updatedRun = Run(id: newRun.id, name: updatedRunName, members: [], active: true, startedOn: Date.now)
        
        // starting the action
        try await startActiveRun(run: updatedRun)
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
        try await addMembersToRun(members: [user], runID: runToJoin.id!)
        
        
        // starting the action
        try await startActiveRun(run: runToJoin)
        
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
        // downloading all the members uploading yourself
        await upDownloadManager()
        
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
    
    /// checks and starts location service
    private func checkAndStartLocationService() {
        if self.locationAuthorization {
            // TODO: check if location is enabled?
            // check if location is enabled
//                        if CLLocationManager.locationServicesEnabled() {
                // starting the location and heading updating + timer for upload and download
                print("Starting location tracking")
                self.locationManager?.startUpdatingLocation()
                self.locationManager?.startUpdatingHeading()

                // starting the upload/download timer
                self.startUploadDownloadTimer()

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
    private func startUploadDownloadTimer() {
        self.runTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.upDownloadManager()
            }
        }
    }
    
    /// uploads user location, and downloads the other members
    func upDownloadManager() async {
        print("UpDownload is running")
        // Upload user location
        do {
            try await uploadUserLocation()
        } catch {
            print("Error uploading user location: \(error)")
        }
        
        // After uploading, load run members
        do {
            try await loadRunMembers()
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
    
    
    /// quit active run: removes user from run, stops run timer, stops updating location, stops updating header, sets location, speed and heading to nil and updates the user in the DB to that
    func quitActiveRun() async throws {
        // reset the active run var
        DispatchQueue.main.async {
            self.runTimer?.invalidate()
            self.runTimer = nil
            
            // make run inactive, keeping the id
            self.activeRun = Run(name: "", members: self.activeRun.members, active: false)
            
            // stop location and header updating
            print("Stopping location tracking")
            self.locationManager?.stopUpdatingLocation()
            self.locationManager?.stopUpdatingHeading()
            
            // set location of user to nil
            self.user.latitude = nil
            self.user.longitude = nil
            self.user.speed = nil
            
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
    func loadRunMembers() async throws {
        print("loading members")
        guard let runID = activeRun.id else {
            print("Error: No active run ID!")
            return }
        
        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members)
        
        let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
        
        DispatchQueue.main.async {
            self.activeRun.members = membersResponse.filter { $0.id != self.user.id }
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
    

    // MARK: User

    @Published var user: Member = Member(id: nil, name: "Your Name")
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
    
    
    
    // MARK: Location
    private var locationManager: CLLocationManager?
    
    private var isUpdatingLocation = false
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.allowsBackgroundLocationUpdates = true
        
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
        
        guard let newLocation = locations.last else { 
            print("Something wrong with locationManager")
            return }
        
        
        DispatchQueue.main.async {
            self.user.latitude = newLocation.coordinate.latitude
            self.user.longitude = newLocation.coordinate.longitude
            var speed = newLocation.speed * 60 * 60 / 1000
            if speed < 0.0 {
                speed = 0.0
            }
            self.user.speed = speed
        }
    }
    
}
