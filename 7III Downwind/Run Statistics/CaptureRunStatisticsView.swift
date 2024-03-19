//
//  CaptureRunStatisticsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 19.03.2024.
//

import SwiftUI

struct CaptureRunStatisticsView: View {
    @ObservedObject var downwindManager: DownwindManager

    var body: some View {
        StatisticsControlCenter(downwindManager: downwindManager, onlyStatistics: true)
            .navigationTitle("Capture Run")
    }
}

#Preview {
    CaptureRunStatisticsView(downwindManager: DownwindManager())
}
