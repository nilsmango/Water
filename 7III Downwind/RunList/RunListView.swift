//
//  RunListView.swift
//  7III Downwind
//
//  Created by Simon Lang on 02.01.24.
//

import SwiftUI

struct RunListView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    private var distances: [Member: Double] {
        var distances = [Member: Double]()
        for member in downwindManager.activeRun.members {
            if let distance = calculateDirectDistance(from: downwindManager.user, to: member) {
                distances[member] = distance
            }
        }
        return distances
    }
    
    @State private var isShowingAlert = false
    
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
//                    Section {
//                        Text("Your data: \(String(downwindManager.user.latitude ?? 0.0)), \(downwindManager.user.longitude ?? 0.0). Speed: \(downwindManager.user.speed ?? 0.0) km/h")
//                        
//                    }
                    Section {
                        ForEach(sortedMembers()) { member in
                            if !(member.onlyWatching ?? false) {
                                MemberListView(member: member, distance: distances[member], degrees: calculateBearingToTarget(myTrueHeading: downwindManager.trueHeading, myLatitude: downwindManager.user.latitude ?? 0.0, myLongitude: downwindManager.user.longitude ?? 0.0, targetLatitude: member.latitude ?? 0.0, targetLongitude: member.longitude ?? 0.0), measurementSystem: downwindManager.measurementSystem, showDetail: downwindManager.showListDetail)
                                
                            }
                            
                        }
                        .onMove(perform: { indices, newOffset in
                            // TODO: move this function into the model (doesn't really make a difference though) and make it work
                            downwindManager.activeRun.members.move(fromOffsets: indices, toOffset: newOffset)
                            downwindManager.runListSorting = .custom
                        })
                    } header: {
                        Text("Time elapsed: \(Text(downwindManager.activeRun.startedOn ?? Date.now, style: .timer))")
                            .monospacedDigit()
                    } footer: {
                        HStack {
                            Spacer()
                            
                            Button {
                                isShowingShareSheet = true
                                
                            } label: {
                                Label("Share Run", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                        }
                        .padding()
                        

                    }
                    
                }
                
                HStack {
                    Button(role: .destructive, action: {
                        isShowingAlert = true
                        
                    }, label: {
                        Label("Exit Run", systemImage: "door.left.hand.open")
                    })
                    .buttonStyle(.bordered)
                    .padding()
                    
                    OptionsMenu(sorting: $downwindManager.runListSorting, measurement: $downwindManager.measurementSystem, showListDetail: $downwindManager.showListDetail)
                        .buttonStyle(.bordered)
                        .padding()
                    
                }
            }
            .alert(isPresented: $isShowingAlert) {
                Alert(
                    title: Text("Are you sure?"),
                    message: Text("There is no turning back."),
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
//                        .navigationTitle("Share Run")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    isShowingShareSheet = false
                                }
                            }
                        }
                }
                
            })
            
            .navigationTitle(downwindManager.activeRun.name)
            .navigationBarTitleDisplayMode(.inline)
            .background(.listBackground)

        }
        
    }
        
        
    func sortedMembers() -> [Member] {
        let stupidlyHighNumber = 10000000000.9
        let stupidlyLowNumber = -1.0
        switch downwindManager.runListSorting {
        case .name:
            return downwindManager.activeRun.members.sorted { $0.name < $1.name }
        case .distanceAscending:
            return downwindManager.activeRun.members.sorted { distances[$0] ?? stupidlyHighNumber < distances[$1] ?? stupidlyHighNumber}
        case .distanceDescending:
            return downwindManager.activeRun.members.sorted { distances[$0] ?? stupidlyLowNumber > distances[$1] ?? stupidlyLowNumber}
        case .custom:
            return downwindManager.activeRun.members
        }
    }
}

#Preview {
    RunListView(downwindManager: DownwindManager())
}
