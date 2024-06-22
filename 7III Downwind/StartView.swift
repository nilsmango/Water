//
//  StartView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct StartView: View {
    @ObservedObject var downwindManager: DownwindManager

    @State private var showRunPicker = false
    @State private var showStartRunSheet = false
    @State private var runType: RunType = .start
    
    @State private var showOptionsSheet = false
    @State private var showAboutSheet = false
    @State private var showCaptureStatistics = false
    
    @State private var showFirstTimeUserName = false
    
    var body: some View {
        NavigationStack {
                    VStack {
                        
                        StatisticsControlCenter(downwindManager: downwindManager)
                            .padding()
                        
                        if downwindManager.activeRun.active {
                            if downwindManager.user.onlyWatching == true {
                                RunMapView(downwindManager: downwindManager)
                            } else {
                                RunListView(downwindManager: downwindManager)
                            }
                        } else {
                            Button(action: {
                                showRunPicker = true
                            }, label: {
                                Label("Online Locations", systemImage: "wifi")
                            })
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .padding(.top, 8)
                        }
                        
                        if downwindManager.developerMode {
                            Toggle("Collect Raw GPS", isOn: $downwindManager.collectRawGPS)
                                .padding()
                            NavigationLink(destination: StatisticTestsView(downwindManager: downwindManager)) {
                                Label("Statistics Test", systemImage: "chart.xyaxis.line")
                            }
                            .buttonStyle(.bordered)
                            .padding()
                        }
                        
                        Spacer()
                        
                    }
                    .navigationTitle("Aloha \(downwindManager.user.name)!")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(destination: StatisticsView(downwindManager: downwindManager)) {
                                Label("Statistics", systemImage: "chart.xyaxis.line")
                                    .labelStyle(.iconOnly)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            StartOptionsMenu(showOptionsSheet: $showOptionsSheet, showAboutSheet: $showAboutSheet)
                        }
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

                .sheet(isPresented: $showFirstTimeUserName, content: {
                    FirstTimeUserNameSet(downwindManager: downwindManager, showingSheet: $showFirstTimeUserName)
                        .interactiveDismissDisabled()
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
                
                .sheet(isPresented: $showAboutSheet, content: {
                    NavigationStack {
                        AboutView(downwindManager: downwindManager)
                            .navigationTitle("About")
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        showAboutSheet = false
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
    StartView(downwindManager: DownwindManager())
}
