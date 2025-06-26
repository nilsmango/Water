//
//  CrownButton.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 31.03.2025.
//

import SwiftUI

struct CrownButton: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    var start: Bool = true
    var metricsMode: Bool = false
    var color: Color { start ? .green : .red}
    @Binding var selection: Tab
    
    @State private var fillPercentage: Double = 0.0
    @State private var gettingTapped = false
    let frameHeight = 52.0
    
    var body: some View {
        
                    ZStack {
                        
                        RoundedRectangle(cornerRadius: 30)
                            .fill(color.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 30)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.3), color]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
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
                        gettingTapped = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            gettingTapped = false
                        }
                    }
            .focusable(!workoutManager.showingSummaryView)
            .digitalCrownRotation(
                detent: $fillPercentage,
                from: 0,
                through: 100,
                by: 2,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            .onChange(of: fillPercentage) { oldValue, newValue in
                if fillPercentage == 100 {
                    fillPercentage = 0
                    WKInterfaceDevice.current().play(.success)
                    if start {
                        workoutManager.checkHealthKitAuthorizationStatus()
                        workoutManager.path.append("session")
                        workoutManager.startWorkout()
                        fillPercentage = 0
                    } else {
                        workoutManager.endWorkout()
                        fillPercentage = 0
                    }
                } else if !start && oldValue > newValue {
                    withAnimation {
                        selection = .metrics
                    }
                }
            }
        }
}

#Preview {
    CrownButton(workoutManager: WorkoutManager(), selection: .constant(.controls))
}
