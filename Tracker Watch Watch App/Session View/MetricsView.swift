//
//  MetricsView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct MetricsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            ElapsedTimeView(
                elapsedTime: 120 * 60 + 15.24,
                showSubseconds: true
            )
                .foregroundColor(.yellow)
                .fontWeight(.semibold)
            
            Text(
                Measurement(
                    value: 2.3,
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
                Text(
                    153.formatted(
                        .number.precision(.fractionLength(0))
                    )
                )
                Image(systemName: "heart.fill")
                    .font(.title2)
                .foregroundColor(.red)
            }
            
            
            Text(
                Measurement(
                    value: 47,
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

#Preview {
    MetricsView()
}
