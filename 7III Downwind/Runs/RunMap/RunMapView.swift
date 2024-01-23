//
//  RunMapView.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2024.
//

import SwiftUI

struct RunMapView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var isShowingAlert = false
    @State private var isShowingShareSheet = false
    @State private var showCoordinatesSheet = false
    
    var body: some View {
        VStack {
            MapView(members: downwindManager.activeRun.members, user: downwindManager.user, measurementSystem: downwindManager.measurementSystem, onlyWatching: true, isShowingSheet: .constant(true))
            
            HStack {
                Button(role: .destructive, action: {
                    isShowingAlert = true
                    
                }, label: {
                    Label("Exit Run", systemImage: "door.left.hand.open")
                })
                .buttonStyle(.bordered)
                .padding()
                
                OptionsMenu(onlyWatching: true, sorting: $downwindManager.runListSorting, measurement: $downwindManager.measurementSystem, showListDetail: $downwindManager.showListDetail, isShowingShareSheet: $isShowingShareSheet, isShowingOtherSheet: $showCoordinatesSheet)
                    .buttonStyle(.bordered)
                    .padding()
                
            }
            
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("Are you sure?"),
                message: Text("There might be no turning back."),
                primaryButton: .destructive(Text("Yes, I am done!")) {
                    Task {
                        do {
                            try await downwindManager.quitActiveRun()
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                },
                secondaryButton: .default(Text("Cancel"))
            )
        }
        .sheet(isPresented: $isShowingShareSheet, content: {
            NavigationStack {
                RunShareView(runName: downwindManager.activeRun.name)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isShowingShareSheet = false
                            }
                        }
                    }
            }
        })
        .sheet(isPresented: $showCoordinatesSheet, content: {
            NavigationStack {
                CoordinatesListView(members: downwindManager.activeRun.members, measurementSystem: downwindManager.measurementSystem)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showCoordinatesSheet = false
                            }
                        }
                    }
            }
        })
    }
}

#Preview {
    RunMapView(downwindManager: DownwindManager())
}
