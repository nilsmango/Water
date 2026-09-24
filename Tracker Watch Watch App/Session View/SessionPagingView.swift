//
//  SessionPagingView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct SessionPagingView: View {
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @ObservedObject var workoutManager: WorkoutManager
    @State private var selection: Tab = .metrics
        
    var body: some View {
        TabView(selection: $selection) {
            ControlsView(workoutManager: workoutManager, selection: $selection).tag(Tab.controls)
            MetricsView(workoutManager: workoutManager).tag(Tab.metrics)
            PlayingView().tag(Tab.nowPlaying)
        }
        .navigationTitle(workoutManager.workoutType.prettyString)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(selection == .nowPlaying)
        .onChange(of: workoutManager.running, { oldValue, newValue in
            if newValue == true {
                displayMetricsView()
            }
        })
        .tabViewStyle(.verticalPage)
        .onChange(of: isLuminanceReduced) { _, _ in
            displayMetricsView()
        }
    }
    
    private func displayMetricsView() {
        withAnimation {
            selection = .metrics
        }
    }
}

#Preview {
    SessionPagingView(workoutManager: WorkoutManager())
}
