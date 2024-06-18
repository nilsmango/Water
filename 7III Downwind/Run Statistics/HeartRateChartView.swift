//
//  HeartRateChartView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI
import Charts

// SwiftUI View to display heart rate chart
struct HeartRateChartView: View {
    
    let measurements: [Date: (Double, Double)] // Data fetched from HealthKit
    
    var body: some View {
//        VStack {
//            Text("Heart Rate Chart")
//                .font(.title)
//                .padding()
            
            // Swift Charts BarChart view
            BarChartView(data: measurements.map { date, span in
                let (min, max) = span
                return BarChartData(id: UUID(), date: date, min: Int(min), max: Int(max))
            })
//            .frame(height: 300)
//            .padding()
//        }
    }
}

// Struct to represent bar chart data
struct BarChartData: Identifiable {
    let id: UUID
    let date: Date
    let min: Int
    let max: Int
}

// SwiftUI View for BarChart using Swift Charts
struct BarChartView: View {
    let data: [BarChartData]
    
    var body: some View {
        Chart(data, id: \.id) {
            BarMark(
                x: .value("", $0.date, unit: .minute),
                yStart: .value("", $0.min),
                yEnd: .value("", $0.max)
//               , width: .fixed(10)
            )
            .clipShape(Capsule())
            .foregroundStyle(.red)
        }
//        .chartXAxis {
//            AxisMarks(values: .stride(by: ChartStrideBy.hour.time)) { _ in
//                AxisValueLabel(
//                            format: .dateTime.hour(.defaultDigits(amPM: .narrow))
//                        )
//            }
//        }
//        .chartYScale(domain: 50...190)
        .frame(height: 150)
    }
}

#Preview {
    HeartRateChartView(measurements: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)])
}
