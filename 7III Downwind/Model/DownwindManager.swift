//
//  DownwindManager.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI
import KeychainSwift

class DownwindManager: ObservableObject {
    // RUN
    @Published var activeRun: Run = Run(name: "", members: [], active: false)
    
    func loadActiveRun() async throws {
        if let userIDString = user.id?.uuidString {
            let url = try createDWURL(endpoint: Endpoints.members + "/" + userIDString + Endpoints.runs)
            
            let dbRunResponse: [DBRun] = try await HTTPClient.shared.fetch(url: url)
                        
            if !dbRunResponse.isEmpty {
                DispatchQueue.main.async {
                let firstDBRun = dbRunResponse.first!
                self.activeRun.id = firstDBRun.id
                self.activeRun.name = firstDBRun.name
                self.activeRun.active = true
                }
            }
            }
        }
    
    
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
    
}
