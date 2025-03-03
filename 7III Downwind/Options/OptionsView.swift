//
//  OptionsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 11.01.24.
//

import SwiftUI
import StoreKit

struct OptionsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showOptionsSheet: Bool
    @Binding var showFirstTimeUserName: Bool
    
    @State private var userName = ""
    @State private var status = ""
    @State private var isShowingAlert = false
    @State private var showUpgradeView = false
    @State private var showManage = false
    
    var body: some View {
        List {
            Section {
                TextField("Kai Lenny Junior", text: $userName)
                    .onAppear {
                        userName = downwindManager.user.name
                    }
                    .onChange(of: userName, { oldValue, newValue in
                        if newValue.count > Constants.maxLengthUser {
                            userName = String(newValue.prefix(Constants.maxLengthUser))
                        }
                    })
            } header: {
                Text("Your Name")
            } footer: {
                if userName != downwindManager.user.name && userName != "" {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            downwindManager.user.name = userName
                            if downwindManager.user.id == nil {
                                downwindManager.user.id = UUID()
                            }
                            downwindManager.saveUser()
//                            Task {
//                                do {
//                                    try await downwindManager.checkAndUpdateUserInDB()
//                                } catch {
//                                    print("Error updating user in user to db: \(error)")
//                                }
//                            }
                            
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
            
            Section {
                TextField("Frothingggggg!", text: $status)
                    .onAppear {
                        status = downwindManager.user.status ?? ""
                    }
                    .onChange(of: status, { oldValue, newValue in
                        if newValue.count > Constants.maxLengthUser {
                            status = String(newValue.prefix(Constants.maxLengthUser))
                        }
                    })
            } header: {
                Text("Your Status")
            } footer: {
                if status != downwindManager.user.status && status != "" {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            downwindManager.user.status = status
                            if downwindManager.user.id == nil {
                                downwindManager.user.id = UUID()
                            }
                            downwindManager.saveUser()
//                            Task {
//                                do {
//                                    try await downwindManager.checkAndUpdateUserInDB()
//                                } catch {
//                                    print("Error updating user in user to db: \(error)")
//                                }
//                            }
                            
                        }, label: {
                            Label("Save", systemImage: "checkmark.circle")
                        })
                        .buttonStyle(.bordered)
                        
                        
                        Spacer()
                        
                        Button(role: .destructive, action: {
                            status = downwindManager.user.status ?? ""
                            
                        }, label: {
                            Label("Cancel", systemImage: "xmark.circle")
                                
                        })
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                    .padding()
                }
                
            }
            
            PremiumSection(downwindManager: downwindManager, showUpgradeView: $showUpgradeView, showManage: $showManage)
            
            Section {
//                Picker("Run List Sorting", selection: $downwindManager.runListSorting) {
//                    ForEach(RunListSorting.allCases) { sortCase in
//                        Text(sortCase.rawValue)
//                    }
//                }
                
                Picker("Measurement System", selection: $downwindManager.measurementSystem) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.rawValue)
                    }
                }
                
//                Toggle(isOn: $downwindManager.showListDetail, label: {
//                    Text("Show List Details")
//                })
                
                
            } header: {
                Text("Other options")
            } footer: {
                HStack {
                    
                    Spacer()
                    
                    Button(role: .destructive, action: {
                        isShowingAlert = true
                        
                    }, label: {
                        Label("Delete All My Data", systemImage: "xmark.circle")
                    })
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding()
            }
            
            Section {
                Text("Find your next wake to thieve in Switzerland with [Next Wave](https://apps.apple.com/ch/app/next-wave/id6739363035).")
            } header: {
                Text("Other Apps")
            }
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("Are you sure?"),
                message: Text("There is no turning back."),
                primaryButton: .destructive(Text("Yes, delete my data!")) {
                    downwindManager.user = Member(id: nil, name: "", status: "", latitude: nil, longitude: nil, createdOn: nil)
                    downwindManager.saveUser()
                    
                    showFirstTimeUserName = true
                    showOptionsSheet = false
                    
                    downwindManager.deleteStatistics()
//                    Task {
//                        do {
//                            try await downwindManager.deleteUserFromDB()
//                        } catch {
//                            print("Error deleting user in db: \(error)")
//                        }
//                    }
                },
                secondaryButton: .default(Text("Cancel"))
            )
        }
        .sheet(isPresented: $showUpgradeView, content: {
            NavigationStack {
                UpgradeView(downwindManager: downwindManager, showUpgradeView: $showUpgradeView)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showUpgradeView = false
                            } label: {
                                Label("Close", systemImage: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .gray)
                            }
                        }
                    }
            }
        })
        .manageSubscriptionsSheet(isPresented: $showManage)
        .onAppear {
            Task {
                await downwindManager.updateCustomerProductStatus()
            }
        }
        .onChange(of: showManage) {
            if showManage == false {
                Task {
                    await downwindManager.updateCustomerProductStatus()
                }
            }
        }
    }
}

#Preview {
    OptionsView(downwindManager: DownwindManager(), showOptionsSheet: .constant(true), showFirstTimeUserName: .constant(true))
}
