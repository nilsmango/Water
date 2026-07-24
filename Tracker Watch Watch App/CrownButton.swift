//
//  CrownButton.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 31.03.2025.
//

import SwiftUI

struct CrownButton: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Environment(\.scenePhase) private var scenePhase

    var start: Bool = true
    var isActive: Bool
    var color: Color { start ? .green : .red }
    @Binding var selection: Tab

    @State private var fillPercentage = 0.0
    @State private var crownPosition = 0.0
    @State private var reverseRotation = 0.0
    @State private var hasTriggeredAction = false
    @State private var gettingTapped = false
    @FocusState private var hasCrownFocus: Bool

    let frameHeight = 52.0
    private let crownLimit = 10_000.0

    private var canHandleCrown: Bool {
        isActive && !workoutManager.showingSummaryView
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(color.opacity(0.2))

            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.3), color]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .frame(height: frameHeight * fillPercentage / 100)
                    }
                }

            if gettingTapped {
                Label("Turn Crown", systemImage: "digitalcrown.arrow.clockwise")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(color)
                    .font(.title3)
                    .fontWeight(.semibold)
            } else {
                Label(start ? "Start" : "End", systemImage: start ? "play" : "xmark")
                    .foregroundStyle(color)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .frame(height: frameHeight)
        .onTapGesture {
            requestCrownFocus()
            gettingTapped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                gettingTapped = false
            }
        }
        .focusable(canHandleCrown)
        .focused($hasCrownFocus)
        .digitalCrownRotation(
            detent: $crownPosition,
            from: -crownLimit,
            through: crownLimit,
            by: 2,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownPosition) { oldValue, newValue in
            handleCrownChange(from: oldValue, to: newValue)
        }
        .onAppear {
            resetInteraction()
            requestCrownFocus()
        }
        .onChange(of: canHandleCrown) { _, newValue in
            if newValue {
                resetInteraction()
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

    private func handleCrownChange(from oldValue: Double, to newValue: Double) {
        guard canHandleCrown, !hasTriggeredAction else { return }

        let change = newValue - oldValue
        if change > 0 {
            reverseRotation = 0
            fillPercentage = min(100, fillPercentage + change)
        } else if change < 0 {
            fillPercentage = max(0, fillPercentage + change)

            if !start {
                reverseRotation += -change
                if reverseRotation >= 6 {
                    reverseRotation = 0
                    withAnimation {
                        selection = .metrics
                    }
                }
            }
        }

        guard fillPercentage >= 100 else { return }

        hasTriggeredAction = true
        fillPercentage = 0
        hasCrownFocus = false
        WKInterfaceDevice.current().play(.success)

        if start {
            workoutManager.checkHealthKitAuthorizationStatus()
            workoutManager.path.append("session")
            workoutManager.startWorkout()
        } else {
            workoutManager.endWorkout()
        }
    }

    private func resetInteraction() {
        fillPercentage = 0
        reverseRotation = 0
        hasTriggeredAction = false
    }

    private func requestCrownFocus() {
        guard canHandleCrown else { return }

        DispatchQueue.main.async {
            guard canHandleCrown else { return }
            hasCrownFocus = true
        }
    }
}

#Preview {
    CrownButton(
        workoutManager: WorkoutManager(),
        isActive: true,
        selection: .constant(.controls)
    )
}
