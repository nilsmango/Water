//
//  HomeView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var showStartRunSheet = false
    
    var body: some View {
        if downwindManager.user.id == nil {
            FirstTimeUserNameSet(downwindManager: downwindManager)
        } else {
            if downwindManager.activeRun.active {
                RunListView(downwindManager: downwindManager)
            } else {
                VStack {
                    Text("Aloha \(downwindManager.user.name)!")
                        .font(.largeTitle)
                        .padding(.bottom, 60)
                    
                    Text("You have not been added to an active run yet.")
                        .padding(.bottom, 30)
                    
                    Button(action: {
                        Task {
                            do {
                                try await downwindManager.loadActiveRun()
                                
                            } catch {
                                print("Error: \(error)")
                            }
                        }
                        
                    }, label: {
                        Label("Check Again", systemImage: "arrow.clockwise.circle")
                    })
                    
                    Text("or")
                    
                    Button(action: {
                        // get all members
                        Task {
                            do {
                                try await downwindManager.fetchAllMembers()
                                
                            } catch {
                                print("Error: \(error)")
                            }
                        }
                        
                        showStartRunSheet = true
                        
                    }, label: {
                        Label("Start New Run", systemImage: "wind.snow")
                    })
                }
                .buttonStyle(.bordered)
                
                .overlay {
                    OverlayAlertView(locationError: $downwindManager.locationError)
                }
                .sheet(isPresented: $showStartRunSheet, content: {
                    NewRunView(downwindManager: downwindManager, showSheet: $showStartRunSheet)
                })
            }
        }
    }
}

#Preview {
    HomeView(downwindManager: DownwindManager())
}
