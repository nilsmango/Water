//
//  HeartRateView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI

struct HeartRateView: View {
    @ObservedObject var downwindManager: DownwindManager

    var heartRates: [Date: (Double, Double)]
    
    @State private var isFetchingData: Bool = false
    
    let startDate: Date?
    let endDate: Date?
    
    let locationData: [LocationData]
    
    // adjusting to 1/5sec
    var speedData: [SpeedSample] {
        guard locationData.count > 1 else { return [] }

        let targetSamples = 300

        let startTime = locationData.first!.timestamp
        let endTime   = locationData.last!.timestamp
        let duration  = endTime.timeIntervalSince(startTime)

        // Minimum bucket size to avoid silly small values
        let bucketSize = max(duration / Double(targetSamples), 1)

        let grouped = Dictionary(grouping: locationData) { data in
            floor(data.timestamp.timeIntervalSince(startTime) / bucketSize)
        }

        return grouped.compactMap { (_, values) in
            let speeds = values.compactMap { $0.speed }
            guard !speeds.isEmpty else { return nil }

            let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)

            // Middle of the bucket looks nicest on charts
            let midTime = values[0].timestamp.addingTimeInterval(bucketSize / 2)

            return SpeedSample(
                date: midTime,
                speedKmh: avgSpeed * 3.6
            )
        }
        .sorted { $0.date < $1.date }
    }
    
    @State private var selectedTime: Double?
    
    var body: some View {
        
        if (!heartRates.isEmpty && heartRates.values.flatMap({ [$0.0, $0.1] }).reduce(0, +) > 30) || speedData.count > 4 {
                                    
            Section {
                VStack {
                    Spacer(minLength: 0.0)
                    HeartRateChartView(measurements: heartRates, speedData: speedData, selectedTime: $selectedTime)

                }
                .frame(height: selectedTime != nil ? 252 : 230)
                
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
            }
        }
    }
}

#Preview {
    List {
        HeartRateView(downwindManager: DownwindManager(), heartRates: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)], startDate: Date().addingTimeInterval(-232323), endDate: Date().addingTimeInterval(-22323), locationData: [])
    }
}
