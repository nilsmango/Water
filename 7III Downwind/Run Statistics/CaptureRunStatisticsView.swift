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
        VStack {
            if downwindManager.activeStatistics == false {
                Button(action: {
                    showCapture = false
                }, label: {
                    Label("Back Home", systemImage: "arrowshape.backward.fill")
                })
                .buttonStyle(.bordered)
                .padding(.bottom)
            }
            
            StatisticsControlCenter(downwindManager: downwindManager, onlyStatistics: true)
        }
        
    }
}

#Preview {
    CaptureRunStatisticsView(downwindManager: DownwindManager(), showCapture: .constant(true))
}
