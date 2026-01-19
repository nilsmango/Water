//
//  HeartRateChartView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI
import Charts


struct BarChartData: Identifiable {
    let id: UUID
    let date: Date
    let min: Double
    let max: Double
}


struct HeartRateChartView: View {
    let measurements: [Date: (Double, Double)]
    let speedData: [SpeedSample]

    var body: some View {
        let data = measurements
            .sorted { $0.key < $1.key }
            .map { date, span in
                let (min, max) = span
                return BarChartData(
                    id: UUID(),
                    date: date,
                    min: min,
                    max: max
                )
            }

        let minYValue = (data.map { $0.min }.min() ?? 0) - 5
        let maxYValue = (data.map { $0.max }.max() ?? 0) + 10

        HeartRateChart(
            data: data,
            minY: minYValue,
            maxY: maxYValue,
            speedData: speedData
        )
    }
}

struct HeartRateChart: View {
    let data: [BarChartData]
    let minY: Double
    let maxY: Double
    let speedData: [SpeedSample]

    @State private var selectedTime: Double?
    
    private var speedMin: Double {
        (speedData.map { $0.speedKmh }.min() ?? 0) - 1
    }

    private var speedMax: Double {
        (speedData.map { $0.speedKmh }.max() ?? 0) + 1
    }
    
    // Get the earliest timestamp from both datasets
    private var startTime: Date {
        let hrStart = data.first?.date ?? Date()
        let speedStart = speedData.first?.date ?? Date()
        return min(hrStart, speedStart)
    }
    
    // Get the latest timestamp from both datasets
    private var endTime: Date {
        let hrEnd = data.last?.date ?? Date()
        let speedEnd = speedData.last?.date ?? Date()
        return max(hrEnd, speedEnd)
    }
    
    // Convert date to seconds from start
    private func secondsFromStart(_ date: Date) -> Double {
        date.timeIntervalSince(startTime)
    }
    
    // Format seconds as MM:SS
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    // Find closest heart rate value to selected time
    private func heartRateAt(time: Double) -> Double? {
        let closest = data.min(by: { abs(secondsFromStart($0.date) - time) < abs(secondsFromStart($1.date) - time) })
        return closest.map { ($0.min + $0.max) / 2 }
    }
    
    // Find closest speed value to selected time
    private func speedAt(time: Double) -> Double? {
        speedData.min(by: { abs(secondsFromStart($0.date) - time) < abs(secondsFromStart($1.date) - time) })?.speedKmh
    }
    
    // Normalize speed to heart rate scale
    private func normalizeSpeed(_ speed: Double) -> Double {
        let speedRange = speedMax - speedMin
        let hrRange = maxY - minY
        return ((speed - speedMin) / speedRange) * hrRange + minY
    }
    
    // Convert normalized value back to speed for axis labels
    private func denormalizeSpeed(_ normalized: Double) -> Double {
        let speedRange = speedMax - speedMin
        let hrRange = maxY - minY
        return ((normalized - minY) / hrRange) * speedRange + speedMin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                Text("km/h")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Spacer()
                Text("bpm")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Chart {
                heartRateMarks
                speedMarks
                
                if let selectedTime {
                    RuleMark(x: .value("Selected", selectedTime))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatTime(selectedTime))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                
                                if let hr = heartRateAt(time: selectedTime) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
                                        Text("\(Int(hr)) bpm")
                                    }
                                    .font(.caption2)
                                }
                                
                                if let speed = speedAt(time: selectedTime) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gauge.open.with.lines.needle.33percent")
                                            .foregroundStyle(.blue)
                                        Text(String(format: "%.1f km/h", speed))
                                    }
                                    .font(.caption2)
                                }
                            }
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 3)
                        }
                }
            }
            .chartXScale(domain: 0...secondsFromStart(endTime))
            .chartYScale(domain: minY...maxY)
            .chartXSelection(value: $selectedTime)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    if let seconds = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatTime(seconds))
                                .font(.caption2)
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartYAxis(content: {
                // Leading axis - Speed (blue)
                AxisMarks(position: .leading, values: .automatic) { value in
                    if let normalized = value.as(Double.self) {
                        let speedValue = denormalizeSpeed(normalized)
                        AxisValueLabel {
                            Text("\(speedValue, specifier: "%.1f")")
                                .foregroundStyle(.blue)
                                .font(.caption2)
                        }
                        AxisTick()
                    }
                }
                
                // Trailing axis - BPM (red)
                AxisMarks(position: .trailing, values: .automatic) { value in
                    if let bpm = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(bpm))")
                                .foregroundStyle(.red)
                                .font(.caption2)
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
            })
            .frame(height: 150)
        }
    }
    
    @ChartContentBuilder
    private var heartRateMarks: some ChartContent {
        ForEach(data) { item in
            LineMark(
                x: .value("Time", secondsFromStart(item.date)),
                y: .value("bpm", (item.min + item.max) / 2),
                series: .value("Metric", "Heart Rate")
            )
            .foregroundStyle(.red)
            .interpolationMethod(.linear)
        }
    }
    
    @ChartContentBuilder
    private var speedMarks: some ChartContent {
        ForEach(speedData, id: \.date) { sample in
            LineMark(
                x: .value("Time", secondsFromStart(sample.date)),
                y: .value("Speed", normalizeSpeed(sample.speedKmh)),
                series: .value("Metric", "Speed")
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.linear)
        }
    }
}



#Preview {
    HeartRateChartView(measurements: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)], speedData: [SpeedSample(date: Date.now, speedKmh: 10), SpeedSample(date: Date.now.addingTimeInterval(-2000), speedKmh: 5), SpeedSample(date: Date.now.addingTimeInterval(-6000), speedKmh: 8)])
}
