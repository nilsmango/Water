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
    
    // MARK: Run
    @Published var activeRun: Run = Run(name: "", members: [], active: false)
    @Published var locationError: LocationError = .none
    
    var runTimer: Timer?
    
    /// creating a new run
    func startNewRun(name: String, members: [Member]) async throws {
        // TODO: testing!
        let url = try createDWURL(endpoint: Endpoints.runs)
        
        // create a new DB run and upload
        let newRun = DBRun(id: UUID(), name: name)
        
        try await HTTPClient.shared.sendData(to: url, object: newRun, httpMethod: HTTPMethods.POST.rawValue)
        
        // add all the members to that run we are creating before
        for member in members {
            let newBaseURL = try createDWURL(endpoint: Endpoints.runs + "/" + newRun.id!.uuidString + Endpoints.members + "/" + member.id!.uuidString)
            print(newBaseURL)
            
            try await HTTPClient.shared.postURL(url: newBaseURL)
        }

    }
    
    /// looking for an active run with the user in it, and starting the UI of the run up
    func loadActiveRun() async throws {
        
        if let userIDString = user.id?.uuidString {
            let url = try createDWURL(endpoint: Endpoints.members + "/" + userIDString + Endpoints.runs)
            
            let dbRunResponse: [DBRun] = try await HTTPClient.shared.fetch(url: url)
            
            if !dbRunResponse.isEmpty {
                // request for location authorization
                locationManager?.requestWhenInUseAuthorization()
                
                DispatchQueue.main.async {
                    let firstDBRun = dbRunResponse.first!
                    self.activeRun.id = firstDBRun.id
                    self.activeRun.name = firstDBRun.name
                    self.activeRun.active = true
                    
                    // check if we have authorization to see location
                    if self.locationAuthorization {
                        // check if location is enabled
//                        if CLLocationManager.locationServicesEnabled() {
                            // starting the location and heading updating + timer for upload and download
                            print("Starting location")
                            self.locationManager?.startUpdatingLocation()
                            self.locationManager?.startUpdatingHeading()

                            // starting the upload/download timer
//                            self.runTimer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(self.upDownloadManager), userInfo: nil, repeats: true)
                        // Ensure the timer is added to the current run loop
//                            RunLoop.current.add(self.runTimer!, forMode: .default)
//                        } else {
//                            // show message can't activate location services -> either your device is in Airplane mode or the device doesn’t have the required hardware
//                            self.locationError = .notPossible
//                        }
                        
                        
                    } else {
                        // show location authorization request again
                        self.locationManager?.requestWhenInUseAuthorization()
                    }
                }
                await upDownloadManager()
            }
        }
    }
    
    /// uploads user location, and if the app is in foreground loads the run members after 20 seconds
    @objc func upDownloadManager() async {
        print("UpDownload is running")
        // Upload user location
        do {
            try await uploadUserLocation()
        } catch {
            print("Error uploading user location: \(error)")
        }
        
        // After uploading, wait for 20 seconds and then load run members
        do {
//            try await Task.sleep(nanoseconds: 20_000_000_000)
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
    private func removeUserFromRun() async throws {
        guard let runID = activeRun.id else {
            print("Error: No active run ID!")
            return
        }
        
        // check if run has only user in it at this point
        if activeRun.members == [] {
            // simply delete the run
            let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString)
            
            Task {
                do {
                    try await HTTPClient.shared.delete(url: url)
                } catch {
                    print("Error \(error)")
                }
            }
            
        } else {
            // remove user
            
            guard let userID = user.id else {
                print("Error: No user ID!")
                return
            }
            
            let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members + "/" + userID.uuidString)
            
            Task {
                do {
                    try await HTTPClient.shared.delete(url: url)
                } catch {
                    print("Error \(error)")
                }
            }
        }
    }
    
    
    /// quit active run: removes user from run, stops run timer, stops updating location, stops updating header, sets location, speed and heading to nil and updates the user in the DB to that
    func quitActiveRun() async throws {
        // reset the active run var
        DispatchQueue.main.async {
            self.runTimer?.invalidate()
            self.runTimer = nil
            
            self.activeRun = Run(name: "", members: [], active: false)
            
            // stop location and header updating
            self.locationManager?.stopUpdatingLocation()
            self.locationManager?.stopUpdatingHeading()
            
            // set location of user to nil
            self.user.latitude = nil
            self.user.longitude = nil
            self.user.speed = nil
            
        }
        // remove user from run / delete run if user is last member
        do {
            try await removeUserFromRun()
        } catch {
            print("Error removing user from run: \(error)")
        }
        
        
        // update the user on db
        do {
            try await uploadUserLocation()
        } catch {
            print("Error uploading user location: \(error)")
        }
    }
    
    // TODO: remove this when not needed any more
//    func locationTesting() {
//        self.locationManager?.startUpdatingLocation()
//        self.locationManager?.startUpdatingHeading()
//    }
    
    func loadRunMembers() async throws {
        print("loading members")
        guard let runID = activeRun.id else {
            print("Error: No active run ID!")
            return }
        
        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members)
        
        let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
        
        DispatchQueue.main.async {
            print("changing up active run with the new members")
            self.activeRun.members = membersResponse.filter { $0.id != self.user.id }
        }
    }
    
    
    
    // MARK: Members
    @Published var availableMembers = [Member]()
    
    
    func fetchAllMembers() async throws {
        let url = try createDWURL(endpoint: Endpoints.members)
        
        let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
        
        DispatchQueue.main.async {
            // remove user
            self.availableMembers = membersResponse.filter { $0.id != self.user.id }
        }
    }
    
    
    
    // MARK: User
    // TODO: check how I create my own username, and see if it is already on the db? check if a run with myself is running?

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
