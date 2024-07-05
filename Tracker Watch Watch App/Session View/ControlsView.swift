//
//  ControlsView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct ControlsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    let currentWatch = WKInterfaceDevice.current()

    var body: some View {
        HStack {
            VStack {
                Button {
                    workoutManager.endWorkout()
                    currentWatch.play(.stop)
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(Color.red)
                .font(.title2)
                .fontWeight(.bold)
                Text("End")
            }
            VStack {
                Button {
                    workoutManager.togglePause()
                    if workoutManager.running {
                        currentWatch.play(.stop)
                    } else {
                        currentWatch.enableWaterLock()
                        currentWatch.play(.start)
                    }
                } label: {
                    Image(systemName: workoutManager.running ? "pause" : "arrow.clockwise")
                }
                .tint(Color.yellow)
                .font(.title2)
                .fontWeight(.bold)
                Text(workoutManager.running ? "Pause" : "Resume")
            }
        }
    }
}

#Preview {
    ControlsView(workoutManager: WorkoutManager())
}
