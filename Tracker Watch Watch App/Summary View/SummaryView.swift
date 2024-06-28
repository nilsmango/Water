//
//  SummaryView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI
import HealthKit

struct SummaryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                
                SummaryMetricView(
                    title: "Total Time",
                    value: durationFormatter.string(from: 30 * 60 + 15) ?? ""
                ).accentColor(Color.yellow)
                
                SummaryMetricView(
                    title: "Total Distance",
                    value: Measurement(
                        value: 1625,
                        unit: UnitLength.meters
                    ).formatted(
                        .measurement(
                            width: .abbreviated,
                            usage: .road
                        )
                    )
                ).accentColor(Color.green)
                
                // TODO: add top speed and ∅-Pace
                
                SummaryMetricView(
                    title: "∅-Heart Rate",
                    value: 143
                        .formatted(
                            .number.precision(.fractionLength(0))
                        )
                    + " bpm"
                ).accentColor(Color.red)
                
                SummaryMetricView(
                    title: "Total Energy",
                    value: Measurement(
                        value: 96,
                        unit: UnitEnergy.kilocalories
                    ).formatted(
                        .measurement(
                            width: .abbreviated,
                            usage: .workout,
                            numberFormatStyle: .number.precision(.fractionLength(0))
                        )
                    )
                ).accentColor(Color.pink)
                
                Text("Activity Rings")
                ActivityRingsView(
                    healthStore: HKHealthStore()
                ).frame(width: 50, height: 50)
                    .padding(.bottom)
                
                Button("Done") {
                    dismiss()
                }
            }
            .scenePadding()
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SummaryView()
}

struct SummaryMetricView: View {
    var title: String
    var value: String

    var body: some View {
        Text(title)
        Text(value)
            .font(.system(.title2, design: .rounded)
                    .lowercaseSmallCaps()
            )
            .foregroundColor(.accentColor)
        Divider()
            .padding(.bottom, 4)
    }
}
