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
    
    @State private var showOptionsSheet = false
    
    @State private var lastCheckDate = Date.now
    
    var body: some View {
        if downwindManager.user.id == nil {
            FirstTimeUserNameSet(downwindManager: downwindManager)
        } else {
            if downwindManager.activeRun.active {
                RunListView(downwindManager: downwindManager)
            } else {
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showOptionsSheet = true
                        }, label: {
                            Label("Options", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        })
                        .padding()
                    }
                    
                    Spacer()
                    
                    Text("Aloha \(downwindManager.user.name)!")
                        .font(.largeTitle)
                        .padding(.bottom, 60)
                    
                    Text("You have not been added to an active run yet.")
                    
                    Text("Last check: \(Text(lastCheckDate, style: .timer))")
                        .monospacedDigit()
                        .padding(.bottom, 30)
                        .onAppear {
                            lastCheckDate = Date.now
                        }
                    
                    Group {
                        Button(action: {
                            Task {
                                do {
                                    try await downwindManager.loadActiveRun()
                                } catch {
                                    print("Error loading active run: \(error)")
                                }
                            }
                            lastCheckDate = Date.now

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
                                    print("Error fetching all members: \(error)")
                                }
                            }
                            
                            showStartRunSheet = true
                            
                        }, label: {
                            Label("Start New Run", systemImage: "wind.snow")
                        })
                    }
                    .buttonStyle(.bordered)
                    
                    
                    
                    Spacer()
                }
                
                
                
                
                .overlay {
                    OverlayAlertView(locationError: $downwindManager.locationError)
                }
                .sheet(isPresented: $showStartRunSheet, content: {
                    NewRunView(downwindManager: downwindManager, showSheet: $showStartRunSheet)
                })
                
                .sheet(isPresented: $showOptionsSheet, content: {
                    NavigationStack {
                        OptionsView(downwindManager: downwindManager)
                            .navigationTitle("Options")
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        showOptionsSheet = false
                                    }
                                }
                            }
                    }
                    
                })
            }
        }
    }
}

#Preview {
    HomeView(downwindManager: DownwindManager())
}
