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
            if downwindManager.activeRun.active {
                if downwindManager.user.onlyWatching == true {
                    RunMapView(downwindManager: downwindManager)
                } else {
                    RunListView(downwindManager: downwindManager)
                }
            } else {
                ZStack {
                    VStack {
                        HStack {
                            Spacer()
                            
                            StartOptionsMenu(showOptionsSheet: $showOptionsSheet, showAboutSheet: $showAboutSheet)
                            .padding()
                        }
                        
                        Spacer()
                        
                        
                        if downwindManager.user.name == "" {
                            Text("You will need to set a name before you can start using this app. Simply tap on the icon in the upper right-hand corner to set a name.")
                        } else {
                            Text("Aloha \(downwindManager.user.name)!")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                        }
                        
                        Spacer()
                        Spacer()
                        
                        if downwindManager.developerMode {
                            Toggle("Collect Raw GPS", isOn: $downwindManager.collectRawGPS)
                                .padding()
                        }
                        
                        
                        HStack {
                            NavigationLink(destination: StatisticsView(downwindManager: downwindManager)) {
                                Label("Statistics", systemImage: "chart.xyaxis.line")
                            }
                            .buttonStyle(.bordered)
                            .padding()
                            
                            if downwindManager.developerMode {
                                NavigationLink(destination: StatisticTestsView(downwindManager: downwindManager)) {
                                    Label("Statistics Test", systemImage: "chart.xyaxis.line")
                                }
                                .buttonStyle(.bordered)
                                .padding()
                            }
                            
                        }
                    }
                    
                    Button(action: {
                        showRunPicker = true
                    }, label: {
                        Text("Start")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 50)
                            .padding(.vertical, 30)
                            .background {
                                Capsule()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color.mint]), startPoint: .top, endPoint: .bottom))
                                                    
                                    .shadow(
                                        color: .black.opacity(0.1),
                                        radius: 7)
                            }
                        
                    })
                    .offset(CGSize(width: 0, height: -9))
                    
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
                    Button("Tracking Statistics only") {
                        showCaptureStatistics = true
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
                
                .fullScreenCover(isPresented: $showCaptureStatistics, content: {
                    NavigationStack {
                        CaptureRunStatisticsView(downwindManager: downwindManager, showCapture: $showCaptureStatistics)
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
                    downwindManager.loadUser()
                    downwindManager.loadRunStatistics()
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
}

#Preview {
    StartView(downwindManager: DownwindManager())
}
