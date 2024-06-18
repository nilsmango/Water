//
//  HeartRateChartView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI
import Charts

struct HeartRateChartView: View {
    let measurements: [Date: (Double, Double)] // Data fetched from HealthKit
    
    var body: some View {
        let data = measurements.map { date, span in
            let (min, max) = span
            return BarChartData(id: UUID(), date: date, min: min, max: max)
        }
        
        let filteredData = data.filter { $0.min >= 30}

        // Calculate min and max Y values
        let minYValue = (filteredData.map { $0.min }.min() ?? 0) - 5
//        let calculatedMinYValue = (data.map { $0.min }.min() ?? 0) - 5
//        let minYValue = max(calculatedMinYValue, 40)
        let maxYValue = (data.map { $0.max }.max() ?? 0) + 10
        
        BarChartView(data: data, minY: minYValue, maxY: maxYValue)
    }
}

struct BarChartData: Identifiable {
    let id: UUID
    let date: Date
    let min: Double
    let max: Double
}

struct BarChartView: View {
    let data: [BarChartData]
    let minY: Double
    let maxY: Double
    
    var body: some View {
        Chart(data, id: \.id) {
            BarMark(
                x: .value("Time", $0.date, unit: .minute),
                yStart: .value("bpm Min", $0.min),
                yEnd: .value("bpm Max", $0.max)
            )
            .clipShape(Capsule())
            .foregroundStyle(.red)
        }
        .chartYScale(domain: minY...maxY)
        .frame(height: 150)
    }
}

#Preview {
    HeartRateChartView(measurements: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)])
}
