//
//  MetricsView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct MetricsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    @State private var heartScale: CGFloat = 0.9
    @State private var animationDuration: Double = 0.5
    
    var body: some View {
        TimelineView(
            MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(), isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .leading) {
                ElapsedTimeView(
                    elapsedTime: workoutManager.builder?.elapsedTime ?? 0,
                    showSubseconds: context.cadence == .live
                )
                .foregroundColor(.yellow)
                .fontWeight(.semibold)
                
                if workoutManager.withGPS {
                    Text(
                        Measurement(
                            value: workoutManager.distance,
                            unit: UnitLength.kilometers
                        ).formatted(
                            .measurement(
                                width: .abbreviated,
                                usage: .road,
                                numberFormatStyle: .number.precision(.fractionLength(1))
                            )
                        )
                    )
                    HStack {
                        Text(workoutManager.makeAveragePaceString())
                        VStack(alignment: .leading, spacing: 0.0) {
                            Text("∅")
                            Text("PACE")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                    }
                    
//                    Text(
//                        Measurement(
//                            value: workoutManager.averageSpeed,
//                            unit: UnitSpeed.metersPerSecond
//                        ).formatted(
//                            .measurement(
//                                width: .abbreviated,
//                                usage: .general,
//                                numberFormatStyle: .number.precision(.fractionLength(1))
//                            )
//                        )
//                    )
                }
                
                
                HStack {
                    Text(
                        workoutManager.heartRate.formatted(
                            .number.precision(.fractionLength(0))
                        )
                    )
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .scaleEffect(heartScale)
                        .animation(
                            .easeInOut(duration: animationDuration).repeatForever(autoreverses: true),
                            value: heartScale
                        )
                        .onChange(of: workoutManager.heartRate) { oldValue, newValue in
                            animationDuration = 60.0 / (newValue * 2)
                            heartScale = heartScale == 0.9 ? 0.95 : 0.9
                        }
                        .onAppear {
                            heartScale = heartScale == 0.9 ? 0.95 : 0.9
                        }
                }
                
                if !workoutManager.withGPS {
                    HStack {
                        Text(
                            workoutManager.averageHeartRate.formatted(
                                .number.precision(.fractionLength(0))
                            )
                        )
                        AverageHeartView()
                    }
                }
                
                Text(
                    Measurement(
                        value: workoutManager.activeEnergy,
                        unit: UnitEnergy.kilocalories
                    ).formatted(
                        .measurement(
                            width: .abbreviated,
                            usage: .workout,
                            numberFormatStyle: .number.precision(.fractionLength(0))
                        )
                    )
                )
            }
            .font(.system(.title, design: .rounded)
                .monospacedDigit()
                .lowercaseSmallCaps()
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
            .padding(.top)
        }
    }
}

#Preview {
    MetricsView(workoutManager: WorkoutManager())
}

private struct MetricsTimelineSchedule: TimelineSchedule {
    var startDate: Date
    var isPaused: Bool

    init(from startDate: Date, isPaused: Bool) {
        self.startDate = startDate
        self.isPaused = isPaused
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var baseSchedule = PeriodicTimelineSchedule(from: self.startDate,
                                                    by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0))
            .entries(from: startDate, mode: mode)
        
        return AnyIterator<Date> {
            guard !isPaused else { return nil }
            return baseSchedule.next()
        }
    }
}
