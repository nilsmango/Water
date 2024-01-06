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
    
    // RUN
    @Published var activeRun: Run = Run(name: "", members: [], active: false)
    
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
                
                // starting the location and heading updating
                    if self.locationAuthorization {
                        if CLLocationManager.locationServicesEnabled() {
                            self.locationManager?.startUpdatingLocation()
                            self.locationManager?.startUpdatingHeading()
                        } else {
                            // TODO: show message can't activate location services -> either your device is in Airplane mode or the device doesn’t have the required hardware
                        }
                        
                        
                    } else {
                        // TODO: show message an't activate location services -> you have to give this app permission for location updates to work as expected.
                        
                    }
                }
            }
            }
        }
    
    // TODO: func quit active run - stop location and heading updating, change user location, speed to nil
    
    
    func loadRunMembers() async throws {
        guard let runID = activeRun.id else {
            print("Error: No active run ID!")
            return }
        
            
        let url = try createDWURL(endpoint: Endpoints.runs + "/" + runID.uuidString + Endpoints.members)
            
            let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
            
            DispatchQueue.main.async {
                self.activeRun.members = membersResponse
            }
        }
    
    

    // Members
    @Published var availableMembers = [Member]()
    
    func fetchMembers() async throws {
        let url = try createDWURL(endpoint: Endpoints.members)
        
        let membersResponse: [Member] = try await HTTPClient.shared.fetch(url: url)
        
        DispatchQueue.main.async {
            self.availableMembers = membersResponse
        }
    }
    
    
    
    // USER
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
    
    // TODO: fetch members, check how I create my own username, and see if it is already on the db? check if a run with myself is running?
    
    // LOCATION
    private var locationManager: CLLocationManager?

    override init() {
            super.init()
            setupLocationManager()
        }

        private func setupLocationManager() {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            
        }
    
    // TODO: if not authorized when in use do show a message when starting a run. activate a overlay via a status @published var in loadingRuns
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            DispatchQueue.main.async {
                self.trueHeading = Double(newHeading.trueHeading)
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let newLocation = locations.last else { return }

            DispatchQueue.main.async {
                self.user.latitude = newLocation.coordinate.latitude
                self.user.longitude = newLocation.coordinate.longitude
                self.user.speed = newLocation.speed * 60 * 60 / 1000
            }
        }

}
