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
    @ObservedObject var dashboards: TrackedElementsManager
    @AppStorage("hasRespondedToReview") var hasRespondedToReviewRequest = false
    
    @State private var userName = ""
    @State private var status = ""
    @State private var isShowingAlert = false
    @State private var showUpgradeView = false
    @State private var showManage = false
    
    var body: some View {
        List {
            PremiumSection(downwindManager: downwindManager, showUpgradeView: $showUpgradeView, showManage: $showManage)
            
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
                Toggle("GPX Run Import Button", isOn: $downwindManager.showGPXImport)
                    .tint(.accent)
                
                Toggle("GPS Tracker", isOn: $downwindManager.showTracker)
                    .tint(.accent)
                
                if downwindManager.appOpened > 4 {
                    Toggle("Review Request", isOn: Binding(
                        get: { !hasRespondedToReviewRequest },
                        set: { hasRespondedToReviewRequest = !$0 }
                    ))
                    .tint(.accent)
                }
            } header: {
                Text("Main View")
            }
            
            Section {
                Picker("Measurement System", selection: $downwindManager.measurementSystem) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.rawValue)
                    }
                }
                
                NavigationLink(destination: FoilingThresholds()) {
                    Text("Foiling Threshold Speeds")
                }
                                
            } header: {
                Text("Tracker Options")
            }
            
            Section {
                Picker("Wind Unit", selection: $dashboards.preferredWindUnit) {
                    ForEach(UnitType.allCases.filter { !$0.isTemperature }, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                
                Picker("Temperature Unit", selection: $dashboards.preferredTempUnit) {
                    ForEach(UnitType.allCases.filter { $0.isTemperature || $0 == .none  }, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            } header: {
                Text("Dashboard Units")
            }
                        
            Section {
                
                Toggle("Auto Grouping Info", isOn: $dashboards.showGroupInfo)
                
                Toggle("Pull Down Info", isOn: Binding(
                    get: { !dashboards.pulledDownList },
                    set: { dashboards.pulledDownList = !$0 }
                ))
            } header: {
                Text("Dashboards Info Display")
            }
            .tint(.accent)
            
            Section {
                
                Stepper(value: $dashboards.maxWaitTime, in: 1...20, step: 0.1) {
                    Text("Total: \(dashboards.maxWaitTime, specifier: "%.1f") s")
                }
                Stepper(value: $dashboards.maxWaitAfterPlaceholder, in: 1...20, step: 0.1) {
                    Text("After Placeholder: \(dashboards.maxWaitAfterPlaceholder, specifier: "%.1f") s")
                }
            } header: {
                Text("Dashboard Element Wait Times")
            } footer: {
                VStack(alignment: .leading) {
                    Text("After Placeholder specifies the time to wait after a placeholder element (no value or a leading dash) is found, to give the website a chance to change it to a real value. Increase this time if you find that you get placeholders even though on the website the real values are displayed.")
                    
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
                    
                    downwindManager.deleteStatistics()
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
        .navigationTitle("Settings")
    }
}

#Preview {
    OptionsView(downwindManager: DownwindManager(), dashboards: TrackedElementsManager())
}
