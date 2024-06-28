//
//  ControlsView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct ControlsView: View {
    @ObservedObject var workoutManager: WorkoutManager

    var body: some View {
        HStack {
            VStack {
                Button {
                    workoutManager.endWorkout()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(Color.red)
                .font(.title2)
                Text("End")
            }
            VStack {
                Button {
                    workoutManager.togglePause()
                } label: {
                    Image(systemName: workoutManager.running ? "pause" : "arrow.clockwise")
                }
                .tint(Color.yellow)
                .font(.title2)
                Text(workoutManager.running ? "Pause" : "Resume")
            }
        }
    }
}

#Preview {
    ControlsView(workoutManager: WorkoutManager())
}
