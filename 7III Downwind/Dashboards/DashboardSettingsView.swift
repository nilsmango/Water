//
//  DashboardSettingsView.swift
//  WebTracker
//
//  Created by Simon Lang on 30.07.2025.
//

import SwiftUI

struct DashboardSettingsView: View {
    @ObservedObject var manager: TrackedElementsManager
    var body: some View {
        List {
            Section {
                Picker("Wind Unit", selection: $manager.preferredWindUnit) {
                    ForEach(UnitType.allCases.filter { !$0.isTemperature }, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                
                Picker("Temperature Unit", selection: $manager.preferredTempUnit) {
                    ForEach(UnitType.allCases.filter { $0.isTemperature || $0 == .none  }, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            } header: {
                Text("Preferred Units")
            }
            
            
            Section {
                
                Toggle("Show Group Info", isOn: $manager.showGroupInfo)
                
                Toggle("Show Pull Down Info", isOn: Binding(
                    get: { !manager.pulledDownList },
                    set: { manager.pulledDownList = !$0 }
                ))
            } header: {
                Text("Dashboards Info Display")
            }
            
            Section {
                
                Stepper(value: $manager.maxWaitTime, in: 1...20, step: 0.1) {
                    Text("Total: \(manager.maxWaitTime, specifier: "%.1f") s")
                }
                Stepper(value: $manager.maxWaitAfterPlaceholder, in: 1...20, step: 0.1) {
                    Text("After Placeholder: \(manager.maxWaitAfterPlaceholder, specifier: "%.1f") s")
                }
            } header: {
                Text("Element Wait Times")
            } footer: {
                Text("After Placeholder specifies the time to wait after a placeholder element (no value or a leading dash) is found, to give the website a chance to change it to a real value. Increase this time if you find that you get placeholders even though on the website the real values are displayed.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardSettingsView(manager: TrackedElementsManager())
    }
}
