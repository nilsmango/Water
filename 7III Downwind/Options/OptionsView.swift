//
//  OptionsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 11.01.24.
//

import SwiftUI

struct OptionsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var userName = ""
    
    var body: some View {
        List {
            Section {
                TextField("Kai Lenny Junior", text: $userName)
                    .onAppear {
                        userName = downwindManager.user.name
                    }
            } header: {
                Text("Your Name")
            } footer: {
                if userName != downwindManager.user.name {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            downwindManager.user.name = userName
                            downwindManager.saveUser()
                            Task {
                                do {
                                    try await downwindManager.checkAndUpdateUserInDB()
                                } catch {
                                    print("Error updating user in user to db: \(error)")
                                }
                            }
                            
                        }, label: {
                            Label("Save", systemImage: "checkmark.circle")
                        })
                        .buttonStyle(.bordered)
                        
                        
                        Spacer()
                        
                        Button(role: .destructive, action: {
                            userName = downwindManager.user.name
                            
                        }, label: {
                            Label("Cancel", systemImage: "xmark.circle")
                                
                        })
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                    .padding()
                }
                
                
                
            }
            
            Section("Other options") {
                Picker("Run List Sorting", selection: $downwindManager.runListSorting) {
                    ForEach(RunListSorting.allCases) { sortCase in
                        Text(sortCase.rawValue)
                    }
                }
                
                Picker("Measurement System", selection: $downwindManager.measurementSystem) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.rawValue)
                    }
                }
                
                Toggle(isOn: $downwindManager.showListDetail, label: {
                    Text("Show List Details")
                })
            }
        }
    }
}

#Preview {
    OptionsView(downwindManager: DownwindManager())
}
