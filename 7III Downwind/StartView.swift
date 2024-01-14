//
//  StartView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct StartView: View {
    @StateObject private var downwindManager = DownwindManager()
    
    @State private var showSplash = true
    
    var body: some View {
        if showSplash {
            SplashView()
                .onAppear {
                    downwindManager.loadUser()
                        Task {
                            do {
                                try await downwindManager.checkAndUpdateUserInDB()
                            } catch {
                                print("Error checking and updating user in db: \(error)")
                            }
                            do {
                                try await downwindManager.loadAllRuns()
                            } catch {
                                print("Error loading active run: \(error)")
                            }
                            do {
                                try await downwindManager.fetchAllMembers()
                            } catch {
                                print("Error fetching all members: \(error)")
                            }
                        }

                    showSplash = false
                }
        } else {
            HomeView(downwindManager: downwindManager)
        }
    }
}

#Preview {
    StartView()
}
