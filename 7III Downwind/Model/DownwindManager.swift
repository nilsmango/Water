//
//  DownwindManager.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI
import KeychainSwift

class DownwindManager: ObservableObject {
    @Published var activeRun: Run = Run(name: "", members: [], active: false)
    
    @Published var availableMembers = [Member]()
    
    
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
    
    
    // TODO: fetch members, check how I create my own username, and see if it is already on the db? check if a run with myself is running?
    
}
