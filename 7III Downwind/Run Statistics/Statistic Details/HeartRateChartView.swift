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
    @Binding var selectedTime: Double?
    
    private var data: [BarChartData] {
        measurements
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
    }
    
    private var minYValue: Double {
        if data.isEmpty {
            return 0
        } else {
            return (data.map { $0.min }.min() ?? 0) - 5
        }
    }
    
    private var maxYValue: Double {
        if data.isEmpty {
            return 200
        } else {
            return (data.map { $0.max }.max() ?? 0) + 10
        }
    }

    var body: some View {
        HeartRateChart(
            data: data,
            minY: minYValue,
            maxY: maxYValue,
            speedData: speedData, selectedTime: $selectedTime
        )
    }
}

struct HeartRateChart: View {
    let data: [BarChartData]
    let minY: Double
    let maxY: Double
    let speedData: [SpeedSample]

    @Binding var selectedTime: Double?
    
    private var speedMin: Double {
        guard !speedData.isEmpty else { return 0 }
        return (speedData.map { $0.speedKmh }.min() ?? 0) - 1
    }

    private var speedMax: Double {
        guard !speedData.isEmpty else { return 20 }
        return (speedData.map { $0.speedKmh }.max() ?? 0) + 1
    }
    
    private var hasHeartRateData: Bool {
        !data.isEmpty
    }

    private var hasSpeedData: Bool {
        !speedData.isEmpty
    }

    // Make startTime safer
    private var startTime: Date {
        if hasHeartRateData && hasSpeedData {
            let hrStart = data.first!.date
            let speedStart = speedData.first!.date
            return min(hrStart, speedStart)
        } else if hasHeartRateData {
            return data.first!.date
        } else if hasSpeedData {
            return speedData.first!.date
        } else {
            return Date() // Fallback
        }
    }

    // Make endTime safer
    private var endTime: Date {
        if hasHeartRateData && hasSpeedData {
            let hrEnd = data.last!.date
            let speedEnd = speedData.last!.date
            return max(hrEnd, speedEnd)
        } else if hasHeartRateData {
            return data.last!.date
        } else if hasSpeedData {
            return speedData.last!.date
        } else {
            return Date() // Fallback
        }
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
        guard !data.isEmpty else { return nil }
        let closest = data.min(by: { abs(secondsFromStart($0.date) - time) < abs(secondsFromStart($1.date) - time) })
        return closest.map { ($0.min + $0.max) / 2 }
    }
    
    // Find closest speed value to selected time
    private func speedAt(time: Double) -> Double? {
        guard !speedData.isEmpty else { return nil }
        return speedData.min(by: { abs(secondsFromStart($0.date) - time) < abs(secondsFromStart($1.date) - time) })?.speedKmh
    }
    
    // Normalize speed to heart rate scale
    private func normalizeSpeed(_ speed: Double) -> Double {
        let speedRange = speedMax - speedMin
        let hrRange = maxY - minY
        guard hrRange > 0, speedRange > 0 else { return minY }
        return ((speed - speedMin) / speedRange) * hrRange + minY
    }
    
    // Convert normalized value back to speed for axis labels
    private func denormalizeSpeed(_ normalized: Double) -> Double {
        let speedRange = speedMax - speedMin
        let hrRange = maxY - minY
        guard hrRange > 0, speedRange > 0 else { return speedMin }
        return ((normalized - minY) / hrRange) * speedRange + speedMin
    }

    // Update speedOnlyEndTime to be safer
    private var speedOnlyEndTime: Double {
        guard hasSpeedData, let lastSpeed = speedData.last else { return 1 }
        return max(1, secondsFromStart(lastSpeed.date))
    }

    // Update the main body to handle empty data
    var body: some View {
        if !hasSpeedData {
            Text("No speed data available")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 200)
        } else if hasHeartRateData {
            dualAxisChart
        } else {
            speedOnlyChart
        }
    }
    
    // Chart with both heart rate and speed
    private var dualAxisChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                Text("km/h")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
                Spacer()
                Text("bpm")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Chart {
                speedMarks
                heartRateMarks
                
                if let selectedTime {
                    RuleMark(x: .value("Selected", selectedTime))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(
                            position: .top,
                            spacing: 0,
                            overflowResolution: .init(
                                x: .fit(to: .chart),
                                y: .disabled
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "stopwatch")
                                    Text(formatTime(selectedTime))
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .font(.caption2)
                                
                                if let hr = heartRateAt(time: selectedTime) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
                                        Text("\(Int(hr)) bpm")
                                            .monospacedDigit()
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .font(.caption2)
                                }
                                
                                if let speed = speedAt(time: selectedTime) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gauge.open.with.lines.needle.33percent")
                                            .foregroundStyle(Color.accentColor)
                                        Text(String(format: "%.1f km/h", speed))
                                            .monospacedDigit()
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .font(.caption2)
                                }
                            }
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
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
                                .foregroundStyle(Color.accentColor)
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
            .frame(height: 200)
            
            Text("min")
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 3)
        }
    }
    
    // Speed-only chart (when no heart rate data)
    private var speedOnlyChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
               Spacer()
                
                Text("km/h")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
            }
            
            
            if !hasSpeedData {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(speedData, id: \.date) { sample in
                        LineMark(
                            x: .value("Time", secondsFromStart(sample.date)),
                            y: .value("Speed", sample.speedKmh),
                            series: .value("Metric", "Speed")
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.linear)
                    }
                    
                    if let selectedTime {
                        RuleMark(x: .value("Selected", selectedTime))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(
                                position: .top,
                                spacing: 0,
                                overflowResolution: .init(
                                    x: .fit(to: .chart),
                                    y: .disabled
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stopwatch")
                                        Text(formatTime(selectedTime))
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .font(.caption2)

                                    if let speed = speedAt(time: selectedTime) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "gauge.open.with.lines.needle.33percent")
                                                .foregroundStyle(Color.accentColor)
                                            Text(String(format: "%.1f km/h", speed))
                                                .monospacedDigit()
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .font(.caption2)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                    }
                }
                .chartXScale(domain: 0...speedOnlyEndTime)
                .chartYScale(domain: speedMin...speedMax)
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
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        if let speed = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(speed, specifier: "%.1f")")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.caption2)
                            }
                            AxisGridLine()
                            AxisTick()
                        }
                    }
                }
                .frame(height: 200)
                
                Text("min")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 3)
            }
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
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.linear)
        }
    }
}



#Preview {
    HeartRateChartView(measurements: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)], speedData: [SpeedSample(date: Date.now, speedKmh: 10), SpeedSample(date: Date.now.addingTimeInterval(-2000), speedKmh: 5), SpeedSample(date: Date.now.addingTimeInterval(-6000), speedKmh: 8)], selectedTime: .constant(3084.4))
    
    HeartRateChartView(measurements: [:], speedData: [SpeedSample(date: Date.now, speedKmh: 10), SpeedSample(date: Date.now.addingTimeInterval(-2000), speedKmh: 5), SpeedSample(date: Date.now.addingTimeInterval(-6000), speedKmh: 8)].sorted(by: { $0.date < $1.date }), selectedTime: .constant(3044.4))
}
