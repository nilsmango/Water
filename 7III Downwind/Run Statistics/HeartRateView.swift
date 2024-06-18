//
//  HeartRateView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI

struct HeartRateView: View {
    @ObservedObject var downwindManager: DownwindManager

    @State private var heartRates: [Date: (Double, Double)] = [:]
    
    @State private var isFetchingData: Bool = false
    
    let startDate: Date?
    let endDate: Date?
    
    @State private var rotation = Angle(degrees: 0)
    
    var body: some View {
        
        if heartRates.isEmpty {
            
            Section {
                
            if isFetchingData {
                HStack {
                    Spacer()
                    Label("Fetching Heart Rate Data", systemImage: "heart.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.accent)
                        .rotationEffect(rotation)
                        .font(.title3)
                    Spacer()
                }
                .onAppear {
                    withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                        rotation = Angle(degrees: 360)
                    }
                }
                
                            } else {
                                    Button(action: {
                                        isFetchingData = true
                                        downwindManager.fetchHeartRatesOverTime(startTime: startDate, endTime: endDate) { heartRateData, _  in
                                                if let heartRateData = heartRateData {
                                                    heartRates = heartRateData
                                                }
                                                isFetchingData = false
                                        }
                                    }, label: {
                                        Label("Fetch Heart Rate", systemImage: "heart.fill")
                                    })
                                }
                            }
        } else {
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
        HeartRateView(downwindManager: DownwindManager(), startDate: Date().addingTimeInterval(-232323), endDate: Date().addingTimeInterval(-22323))
    }
}
