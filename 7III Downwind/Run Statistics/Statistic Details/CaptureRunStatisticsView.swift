//
//  CaptureRunStatisticsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 19.03.2024.
//

import SwiftUI

struct CaptureRunStatisticsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showCapture: Bool

    var body: some View {
        NavigationStack {
            StatisticsControlCenter(downwindManager: downwindManager, onlyStatistics: true)
        }
        .navigationTitle("Tracking Statistics")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if downwindManager.activeStatistics == false {
                    Button(action: {
                        showCapture = false
                    }, label: {
                        Text("← Back")
                    })
                    .tint(.red)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CaptureRunStatisticsView(downwindManager: DownwindManager(), showCapture: .constant(true))
    }
}
