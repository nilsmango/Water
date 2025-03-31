//
//  ControlsView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct ControlsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @AppStorage("CrownMode") var crownMode: Bool = false

    
    var body: some View {
        VStack {
            if crownMode {
                CrownButton(workoutManager: workoutManager, start: false)
            } else {
                Button {
                    workoutManager.endWorkout()
                    
                } label: {
                    Label("End", systemImage: "xmark")
                }
                .tint(Color.red)
                .font(.title3)
                .fontWeight(.semibold)
            }
                
//            VStack {
//                Button {
//                    workoutManager.togglePause()
//                    if workoutManager.running {
//                        currentWatch.play(.stop)
//                    } else {
//                        currentWatch.enableWaterLock()
//                        currentWatch.play(.start)
//                    }
//                } label: {
//                    Image(systemName: workoutManager.running ? "pause" : "arrow.clockwise")
//                }
//                .tint(Color.yellow)
//                .font(.title2)
//                .fontWeight(.bold)
//                Text(workoutManager.running ? "Pause" : "Resume")
//            }
        }
        .padding()
    }
}

#Preview {
    ControlsView(workoutManager: WorkoutManager())
}
