//
//  OptionsSheetView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 31.03.2025.
//

import SwiftUI

struct OptionsSheetView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @AppStorage("CrownMode") var crownMode: Bool = false
    
    var body: some View {
        List {
            Section {
                Toggle("Digital Crown Mode", isOn: $crownMode)
                    .tint(.accent)
            } footer: {
                Label("Restricts starting and ending workouts to the Digital Crown.", systemImage: "info.circle")
            }
            
            Section {
                Toggle("Keep Selected Hashtags", isOn: $workoutManager.keepHashtags)
                    .tint(.accent)
            }
            
            Section {
                Toggle("Use GPS", isOn: $workoutManager.withGPS)
                    .tint(.accent)
            } footer: {
                Text("\nApp Version: \(workoutManager.currentAppVersion) \(workoutManager.currentAppBuild)")
            }
        }
        .navigationTitle("Options")
    }
}

#Preview {
    NavigationStack {
        OptionsSheetView(workoutManager: WorkoutManager())
    }
}
