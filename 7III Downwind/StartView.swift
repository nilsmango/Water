//
//  StartView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct StartView: View {
    @StateObject private var downwindManager = DownwindManager()
    
    @State private var showRunPicker = false
    @State private var showStartRunSheet = false
    @State private var runType: RunType = .start
    
    @State private var showOptionsSheet = false
    
    @State private var showFirstTimeUserName = false
    
    var body: some View {
        if downwindManager.activeRun.active {
            if downwindManager.user.onlyWatching == true {
                RunMapView(downwindManager: downwindManager)
            } else {
                RunListView(downwindManager: downwindManager)
            }
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
                
                Image("DWSplash")
                    .padding(.bottom, 55)
                
                if downwindManager.user.name == "" {
                    Text("You will need to set a name before you can start using this app. Simply tap on the icon in the upper right-hand corner to set a name.")
                        .padding()
                } else {
                    Text("Aloha \(downwindManager.user.name)!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 60)
                    
                    Button(action: {
                        showRunPicker = true
                    }, label: {
                        Label("Start", systemImage: "wind")
                    })
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            
            .overlay {
                OverlayAlertView(showAlert: $downwindManager.locationError, text: """
    Can't activate location services.
    Either your device is in Airplane mode or the device doesn’t have the required hardware.
    Please deactivate Airplane mode and try again.
    """)
            }
            .confirmationDialog("Pick Run Option", isPresented: $showRunPicker, actions: {
                Button("Start New Run") {
                    runType = .start
                    showStartRunSheet = true
                }
                Button("Join a Run") {
                    runType = .join
                    showStartRunSheet = true
                }
                Button("Watch a Run") {
                    runType = .watch
                    showStartRunSheet = true
                }
            })
            .sheet(isPresented: $showStartRunSheet, content: {
                NavigationStack {
                    StartRun(downwindManager: downwindManager, showSheet: $showStartRunSheet, runType: runType)
                        .navigationTitle(runType.buttonLabel)
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
            
            .fullScreenCover(isPresented: $showFirstTimeUserName, content: {
                FirstTimeUserNameSet(downwindManager: downwindManager, showingSheet: $showFirstTimeUserName)
            })
            .sheet(isPresented: $showOptionsSheet, content: {
                NavigationStack {
                    OptionsView(downwindManager: downwindManager, showOptionsSheet: $showOptionsSheet, showFirstTimeUserName: $showFirstTimeUserName)
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
                    .foregroundStyle(.listBackground)
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
