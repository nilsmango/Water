//
//  StartView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct StartView: View {
    @StateObject private var downwindManager = DownwindManager()
    
    @State private var showStartRunSheet = false
    @State private var showJoinRunSheet = false
    
    @State private var showOptionsSheet = false
    
    @State private var showFirstTimeUserName = false
        
    var body: some View {
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
                    .fontWeight(.bold)
                    .padding(.bottom, 60)
                
                Group {
                    Button(action: {
                        // join a run
                        showJoinRunSheet = true
                    }, label: {
                        Label("Join A Run", systemImage: "wind")
                    })
                    
                    Text("or")
                    
                    Button(action: {
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
                NavigationStack {
                    StartRun(downwindManager: downwindManager, showSheet: $showStartRunSheet, isNewRun: true)
                        .navigationTitle("New Run")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Cancel") {
                                    showStartRunSheet = false
                                }
                            }
                        }
                }
            })
            .sheet(isPresented: $showJoinRunSheet, content: {
                NavigationStack {
                    StartRun(downwindManager: downwindManager, showSheet: $showStartRunSheet, isNewRun: false)
                        .navigationTitle("Join Run")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Cancel") {
                                    showJoinRunSheet = false
                                }
                            }
                        }
                }
            })
            .fullScreenCover(isPresented: $showFirstTimeUserName, content: {
                FirstTimeUserNameSet(downwindManager: downwindManager, showingSheet: $showFirstTimeUserName)
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
        
            .background {
                Rectangle()
                    .ignoresSafeArea()
                    .foregroundStyle(Color("ListBackground"))
            }
            .onAppear {
                downwindManager.loadUser()
                if downwindManager.user.id == nil {
                    showFirstTimeUserName = true
                } else {
                    Task {
                        do {
                            try await downwindManager.checkAndUpdateUserInDB()
                        } catch {
                            print("error checking updating user: \(error)")
                        }
                    }
                }
        }
            
        }
        
    }
}

#Preview {
    StartView()
}
