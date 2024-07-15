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
    
    @Environment(\.requestReview) private var requestReview

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
                    //                            Button(action: {
                    //                                showRunPicker = true
                    //                            }, label: {
                    //                                Label("Online Locations", systemImage: "wifi")
                    //                            })
                    //                            .buttonStyle(.bordered)
                    //                            .tint(.accentColor)
                    //                            .padding(.top, 8)
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
            .navigationTitle(downwindManager.user.name.isEmpty ? "Aloha!" : "Aloha \(downwindManager.user.name)!")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: StatisticsView(downwindManager: downwindManager)) {
                        Label("Statistics", systemImage: "chart.xyaxis.line")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StartOptionsMenu(downwindManager: downwindManager, showOptionsSheet: $showOptionsSheet, showAboutSheet: $showAboutSheet)
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
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showStartRunSheet = false
                                } label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                }
                            }
                        }
                }
            })
            .sheet(isPresented: $downwindManager.showUpgradeSheet, content: {
                NavigationStack {
                    UpgradeView(downwindManager: downwindManager, showUpgradeView: $downwindManager.showUpgradeSheet)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    downwindManager.showUpgradeSheet = false
                                } label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                }
                            }
                        }
                }
            })
            
            .sheet(isPresented: $showFirstTimeUserName, content: {
                FirstTimeUserNameSet(downwindManager: downwindManager, showingSheet: $showFirstTimeUserName)
                    .interactiveDismissDisabled()
            })
            
            .sheet(isPresented: $downwindManager.showingSummarySheet, content: {
                SummaryView(downwindManager: downwindManager)
            })
            
            .sheet(isPresented: $showOptionsSheet, content: {
                NavigationStack {
                    OptionsView(downwindManager: downwindManager, showOptionsSheet: $showOptionsSheet, showFirstTimeUserName: $showFirstTimeUserName)
                        .navigationTitle("Options")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showOptionsSheet = false
                                } label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                }
                            }
                        }
                }
            })
            
            .onChange(of: downwindManager.showPromptForReview, { oldValue, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        requestReview()
                        downwindManager.showPromptForReview = false
                    }
                }
            })
            
            .background(.listBackground)
            
            //                .onAppear {
            //                    if downwindManager.user.id == nil {
            //                        showFirstTimeUserName = true
            //                    }
            //                }
        }
        
    }
}

#Preview {
    StartView(downwindManager: DownwindManager())
}
