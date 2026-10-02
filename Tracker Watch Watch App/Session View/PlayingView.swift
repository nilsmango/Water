//
//  PlayingView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 31.03.2025.
//

import SwiftUI
import WatchKit

struct PlayingView: View {
    @AppStorage("CrownMode") private var crownMode = false
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selection: Tab
    var isActive: Bool

    @State private var crownPosition = 0.0
    @FocusState private var hasCrownFocus: Bool

    var body: some View {
        ZStack {
            NowPlayingView()

            if crownMode {
                Rectangle()
                    .fill(.clear)
                    .focusable(isActive)
                    .focused($hasCrownFocus)
                    .digitalCrownRotation(
                        detent: $crownPosition,
                        from: -10_000,
                        through: 10_000,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .onChange(of: crownPosition) { oldValue, newValue in
                        guard crownMode, isActive else { return }

                        // Keep the system Now Playing volume control from
                        // taking crown focus; crown-up returns to the metrics page.
                        if newValue > oldValue {
                            withAnimation {
                                selection = .metrics
                            }
                        }
                    }
                    .allowsHitTesting(false)
            }
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
        .onChange(of: crownMode) { _, newValue in
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
        guard crownMode, isActive else { return }

        DispatchQueue.main.async {
            guard crownMode, isActive else { return }
            hasCrownFocus = true
        }
    }
}

#Preview {
    PlayingView(selection: .constant(.nowPlaying), isActive: true)
}
