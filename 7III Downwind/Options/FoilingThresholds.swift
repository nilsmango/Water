//
//  FoilingThresholds.swift
//  7III Tracker
//
//  Created by Simon Lang on 13.05.2025.
//

import SwiftUI

struct FoilingThresholds: View {
    @State private var thresholdOverrides: [WorkoutType: Double] = [:]
    
    var body: some View {
        Form {
            Section {
                ForEach(WorkoutType.allCases.filter { $0.calculateFoilingStats }, id: \.self) { type in
                    HStack {
                        Text(type.prettyString + ":")
                        Spacer()
                        Stepper(value: binding(for: type), in: 0...100, step: 0.1) {
                            Text(String(format: "%.1f", thresholdOverrides[type] ?? 0) + " km/h")
                        }
                    }
                }
            }
        }
        .onAppear {
            for type in WorkoutType.allCases where type.calculateFoilingStats {
                thresholdOverrides[type] = type.thresholdSpeedKmhSlowSpeedWithDefault
            }
        }
        .navigationTitle("Foiling Threshold Speeds")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func binding(for type: WorkoutType) -> Binding<Double> {
        Binding(
            get: { thresholdOverrides[type] ?? 0 },
            set: {
                thresholdOverrides[type] = $0
                WorkoutType.setThreshold($0, for: type)
            }
        )
    }
}

#Preview {
    FoilingThresholds()
}
