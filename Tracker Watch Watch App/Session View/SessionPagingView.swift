//
//  SessionPagingView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI
import WatchKit

struct SessionPagingView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    @State private var selection: Tab = .metrics
    
    enum Tab {
    case controls, metrics, nowPlaying
    }
    
    var body: some View {
        TabView(selection: $selection) {
            ControlsView(workoutManager: workoutManager).tag(Tab.controls)
            MetricsView().tag(Tab.metrics)
            NowPlayingView().tag(Tab.nowPlaying)
        }
        .onChange(of: workoutManager.running, { oldValue, newValue in
            if newValue == true {
                displayMetricsView()
            }
            })
        .navigationTitle(workoutManager.workoutType.prettyString)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(selection == .nowPlaying)
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
