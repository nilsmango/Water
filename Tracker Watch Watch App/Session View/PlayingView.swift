//
//  PlayingView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 31.03.2025.
//

import SwiftUI
import WatchKit

struct PlayingView: View {
    @Binding var selection: Tab
    @State private var crownValue = 0.0
    
    var body: some View {
        NowPlayingView()
            .focusable()
            .digitalCrownRotation($crownValue, from: 0, through: 2, by: 1, sensitivity: .medium, isContinuous: false)
            .onChange(of: crownValue) {
                selection = .controls
                crownValue = 0
            }
    }
}

#Preview {
    PlayingView(selection: .constant(.nowPlaying))
}
