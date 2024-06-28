//
//  Tracker_WatchApp.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

@main
struct Tracker_Watch_Watch_AppApp: App {
    @StateObject private var workoutManager = WorkoutManager()
        
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $workoutManager.path) {
                StartView(workoutManager: workoutManager)
                    .navigationDestination(for: String.self) { _ in
                        SessionPagingView(workoutManager: workoutManager)
                    }
            }
            .sheet(isPresented: $workoutManager.showingSummaryView) {
                SummaryView(workoutManager: workoutManager)
            }
        }
    }
}
