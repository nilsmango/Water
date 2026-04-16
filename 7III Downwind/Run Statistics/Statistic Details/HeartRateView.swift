//
//  HeartRateView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI
import Charts

struct HeartRateView: View {
    @ObservedObject var downwindManager: DownwindManager

    var heartRates: [Date: (Double, Double)]
    
    @State private var isFetchingData: Bool = false
    
    let startDate: Date?
    let endDate: Date?
    
    let speedData: [SpeedSample]
    
    @State private var selectedTime: Double?
    
    var body: some View {
        
        if (!heartRates.isEmpty && heartRates.values.flatMap({ [$0.0, $0.1] }).reduce(0, +) > 30) || speedData.count > 4 {
                                     
            Section {
                VStack {
                    Spacer(minLength: 0.0)
                    HeartRateChartView(measurements: heartRates, speedData: speedData, selectedTime: $selectedTime)

                }
                .frame(height: selectedTime != nil ? 274 : 253)
                
            } header: {
                HStack {
                    Text("Heart Rate & Speed")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    
                }
                .padding(.bottom, 9)
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "info.circle")
                    Text("Drag the chart for exact values. Tap to dismiss.")
                }
            }
        }
    }
}

private struct SpeedDistributionBin: Identifiable {
    let lowerBound: Double
    let upperBound: Double
    let percentage: Double
    
    var id: Double { lowerBound }
    var axisValue: Double { lowerBound }
}

struct SpeedDistributionView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    let speedData: [SpeedSample]
    
    @State private var selectedSpeed: Double?
    @State private var bins: [SpeedDistributionBin] = []
    @State private var domainUpperBound: Double = 1
    @State private var maxPercentage: Double = 10
    @State private var binWidth: Double = 1
    @State private var sampleCount: Int = 0
    @State private var lastCacheKey: Int?
    
    private var unitLabel: String {
        downwindManager.measurementSystem == .imperial ? "mph" : "km/h"
    }
    
    private var selectedBin: SpeedDistributionBin? {
        guard let selectedSpeed else { return nil }
        return bins.min(by: { abs($0.axisValue - selectedSpeed) < abs($1.axisValue - selectedSpeed) })
    }
    
    private var chartDomain: ClosedRange<Double> {
        -0.5...(domainUpperBound + 1.0)
    }
    
    var body: some View {
        Group {
            Section {
                if sampleCount > 4, !bins.isEmpty {
                    VStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Chart {
                                ForEach(bins) { bin in
                                    BarMark(
                                        x: .value("Speed", bin.axisValue),
                                        y: .value("Distribution", bin.percentage)
                                    )
                                    .position(by: .value("Type", "GPS Speed"))
                                    .foregroundStyle(color(for: bin))
                                    .opacity(selectedBin?.id == bin.id ? 1.0 : 0.9)
                                }
                                
                                if let selectedBin {
                                    RuleMark(x: .value("Selected", selectedBin.axisValue))
                                        .foregroundStyle(.gray.opacity(0.5))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                        .annotation(
                                            position: .overlay,
                                            alignment: .center,
                                            overflowResolution: .init(
                                                x: .fit(to: .chart),
                                                y: .fit(to: .chart)
                                            )
                                        ) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "gauge.open.with.lines.needle.33percent")
                                                        .foregroundStyle(color(for: selectedBin))
                                                    Text("\(formatSpeed(selectedBin.lowerBound)) \(unitLabel)")
                                                        .fontWeight(.semibold)
                                                        .monospacedDigit()
                                                        .lineLimit(1)
                                                        .fixedSize(horizontal: true, vertical: false)
                                                }
                                                .font(.caption2)
                                                
                                                HStack(spacing: 4) {
                                                    Image(systemName: "chart.bar.fill")
                                                        .foregroundStyle(.secondary)
                                                    Text("\(selectedBin.percentage, specifier: "%.1f")% of samples")
                                                        .monospacedDigit()
                                                        .lineLimit(1)
                                                        .fixedSize(horizontal: true, vertical: false)
                                                }
                                                .font(.caption2)
                                            }
                                            .padding(8)
                                            .background(Color(.systemBackground).opacity(0.8))
                                            .cornerRadius(8)
                                        }
                                }
                            }
                            .chartXScale(domain: chartDomain)
                            .chartYScale(domain: 0...maxPercentage)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                                    if let speed = value.as(Double.self) {
                                        AxisValueLabel {
                                            Text(formatAxisSpeed(speed))
                                                .font(.caption2)
                                        }
                                        AxisGridLine()
                                        AxisTick()
                                    }
                                }
                            }
                            .chartOverlay { chartProxy in
                                speedDistributionSelectionOverlay(chartProxy: chartProxy)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic) { value in
                                    if let percentage = value.as(Double.self) {
                                        AxisValueLabel {
                                            Text("\(Int(percentage.rounded()))%")
                                                .font(.caption2)
                                        }
                                        AxisGridLine()
                                        AxisTick()
                                    }
                                }
                            }
                            .frame(height: 200)
                            
                            Text(unitLabel)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 5)
                        }
                    }
                    .frame(height: 226)
                } else if !speedData.isEmpty {
                    Text("Not enough GPS speed samples for a distribution yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No GPS speed data available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text("GPS Speed Distribution")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.bottom, 9)
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "info.circle")
                    Text("Drag the chart for exact values. Tap to dismiss.")
                }
            }
        }
        .onAppear {
            if downwindManager.forcePremiumForScreenshots && !speedData.isEmpty && bins.isEmpty {
                let result = buildSpeedDistribution(from: speedData, system: downwindManager.measurementSystem)
                bins = result.bins
                domainUpperBound = result.domainUpperBound
                maxPercentage = result.maxPercentage
                binWidth = result.binWidth
                sampleCount = result.sampleCount
                lastCacheKey = cacheKey
            }
        }
        .task(id: cacheKey) {
            await rebuildDistributionIfNeeded()
        }
        .onChange(of: downwindManager.measurementSystem) { _, _ in
            selectedSpeed = nil
        }
    }
    
    private func color(for bin: SpeedDistributionBin) -> Color {
        let normalizedSpeed = domainUpperBound > 0 ? min(max(bin.axisValue / domainUpperBound, 0), 1) : 0
        return Color(uiColor: colorForSpeed(normalizedSpeed))
    }
    
    private func formatAxisSpeed(_ speed: Double) -> String {
        "\(Int(speed.rounded()))"
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if binWidth < 1 {
            return String(format: "%.1f", speed)
        }
        
        if speed >= 10 {
            return "\(Int(speed.rounded()))"
        } else {
            return String(format: "%.1f", speed)
        }
    }
    
    private func speedDistributionSelectionOverlay(chartProxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            let plotFrame = geometry[chartProxy.plotAreaFrame]
            
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            let relativeX = min(max(0, value.location.x - plotFrame.origin.x), plotFrame.size.width)
                            
                            if let selectedValue = chartProxy.value(atX: relativeX, as: Double.self) {
                                selectedSpeed = min(max(chartDomain.lowerBound, selectedValue), chartDomain.upperBound)
                            }
                        }
                )
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let relativeX = min(max(0, value.location.x - plotFrame.origin.x), plotFrame.size.width)
                            
                            if selectedSpeed != nil {
                                selectedSpeed = nil
                            } else if let selectedValue = chartProxy.value(atX: relativeX, as: Double.self) {
                                selectedSpeed = min(max(chartDomain.lowerBound, selectedValue), chartDomain.upperBound)
                            }
                        }
                )
        }
    }
    
    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(speedData.count)
        hasher.combine(speedData.first?.date.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(speedData.last?.date.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(downwindManager.measurementSystem)
        return hasher.finalize()
    }
    
    @MainActor
    private func rebuildDistributionIfNeeded() async {
        guard lastCacheKey != cacheKey else { return }
        lastCacheKey = cacheKey
        
        let measurementSystem = downwindManager.measurementSystem
        let sourceData = speedData
        
        let result = await Task.detached(priority: .userInitiated) {
            buildSpeedDistribution(from: sourceData, system: measurementSystem)
        }.value
        
        bins = result.bins
        domainUpperBound = result.domainUpperBound
        maxPercentage = result.maxPercentage
        binWidth = result.binWidth
        sampleCount = result.sampleCount
        selectedSpeed = nil
    }
}

private func buildSpeedDistribution(
    from speedData: [SpeedSample],
    system: MeasurementSystem
) -> (bins: [SpeedDistributionBin], domainUpperBound: Double, maxPercentage: Double, binWidth: Double, sampleCount: Int) {
    let localMetersPerMile = 1609.344
    
    let speeds = speedData.compactMap { sample -> Double? in
        guard sample.speedKmh.isFinite, sample.speedKmh >= 0 else {
            return nil
        }
        
        switch system {
        case .metric:
            return sample.speedKmh
        case .imperial:
            return sample.speedKmh * 1000 / localMetersPerMile
        }
    }
    
    let maxSpeed = speeds.max() ?? 0
    let sampleCount = speeds.count
    
    guard sampleCount > 4, maxSpeed > 0 else {
        return ([], 1, 10, 1, sampleCount)
    }
    
    let binWidth = 1.0
    let domainUpperBound = max(2, ceil(maxSpeed))
    
    let totalBinCount = max(1, Int(domainUpperBound.rounded(.up)) + 1)
    var counts = Array(repeating: 0, count: totalBinCount)
    
    for speed in speeds {
        let rawIndex = Int(speed.rounded())
        let clampedIndex = min(max(rawIndex, 0), totalBinCount - 1)
        counts[clampedIndex] += 1
    }
    
    let totalCount = Double(sampleCount)
    let bins = counts.enumerated().map { index, count in
        let lower = Double(index) * binWidth
        let upper = lower + binWidth
        
        return SpeedDistributionBin(
            lowerBound: lower,
            upperBound: upper,
            percentage: totalCount > 0 ? (Double(count) / totalCount) * 100 : 0
        )
    }
    
    let maxPercentage = max(10, (bins.map(\.percentage).max() ?? 0) * 1.2)
    return (bins, domainUpperBound, maxPercentage, binWidth, sampleCount)
}

#Preview {
    List {
        HeartRateView(downwindManager: DownwindManager(), heartRates: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)], startDate: Date().addingTimeInterval(-232323), endDate: Date().addingTimeInterval(-22323), speedData: [])
        SpeedDistributionView(downwindManager: DownwindManager(), speedData: [SpeedSample(date: Date.now, speedKmh: 10), SpeedSample(date: Date.now.addingTimeInterval(-2000), speedKmh: 5), SpeedSample(date: Date.now.addingTimeInterval(-6000), speedKmh: 8)].sorted(by: { $0.date < $1.date }))
    }
}
