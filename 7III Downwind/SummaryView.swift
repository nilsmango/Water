//
//  SummaryView.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.07.2024.
//

import SwiftUI

struct SummaryView: View {
    @ObservedObject var downwindManager: DownwindManager

    var body: some View {
        if downwindManager.workout == nil {
                ProgressView("Saving Workout")
        } else {
            Label("Workout Saved", systemImage: "checkmark")
        }
    }
}

#Preview {
    SummaryView(downwindManager: DownwindManager())
}
