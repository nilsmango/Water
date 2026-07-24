//
//  PlayingView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 31.03.2025.
//

import SwiftUI
import WatchKit

struct PlayingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selection: Tab
    var isActive: Bool
    @State private var crownValue = 0.0
    @FocusState private var hasCrownFocus: Bool

    var body: some View {
        NowPlayingView()
            .focusable(isActive)
            .focused($hasCrownFocus)
            .digitalCrownRotation(
                $crownValue,
                from: -10_000,
                through: 10_000,
                by: 1,
                sensitivity: .medium,
                isContinuous: false
            )
            .onChange(of: crownValue) {
                guard isActive else { return }
                selection = .controls
            }
            .onAppear {
                requestCrownFocus()
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    requestCrownFocus()
                } else {
                    hasCrownFocus = false
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    requestCrownFocus()
                }
            }
    }

    private func requestCrownFocus() {
        guard isActive else { return }

        DispatchQueue.main.async {
            guard isActive else { return }
            hasCrownFocus = true
        }
    }
}

#Preview {
    PlayingView(selection: .constant(.nowPlaying), isActive: true)
}
