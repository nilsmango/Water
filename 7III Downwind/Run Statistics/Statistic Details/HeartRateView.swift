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
    
    @State private var rotation = Angle(degrees: 0)
    
    var body: some View {
        
        if !heartRates.isEmpty && heartRates.values.flatMap({ [$0.0, $0.1] }).reduce(0, +) > 30 {
                                    
            Section {
                HeartRateChartView(measurements: heartRates)
                
            } header: {
                HStack {
                    Text("Heart Rate")
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
        HeartRateView(downwindManager: DownwindManager(), heartRates: [Date.now : (140, 150), Date.now.addingTimeInterval(-2000) : (100, 105), Date.now.addingTimeInterval(-6000) : (60, 105)], startDate: Date().addingTimeInterval(-232323), endDate: Date().addingTimeInterval(-22323))
    }
}
