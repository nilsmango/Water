//
//  StatisticsControlCenter.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

struct StatisticsControlCenter: View {
    @ObservedObject var downwindManager: DownwindManager
    var onlyStatistics: Bool = false
    
    @State private var tags = [String]()
    
    @State private var showTagsEditView = false
    
    var body: some View {
        ScrollView {
        if downwindManager.activeStatistics == false {
            
                VStack {
                    HStack {
                        Button {
                            downwindManager.startStatistic(onlyStatistics: onlyStatistics, tags: tags)
                            downwindManager.activeRun.startedOn = Date.now
                        } label: {
                            Label("Start Tracking", systemImage: "play.fill")
                        }
                        .buttonStyle(.bordered)
                        .padding()
                        
                        Menu {
                            ForEach(WorkoutType.allCases, id: \.self) { type in
                                Button(action: {
                                    downwindManager.workoutType = type
                                }) {
                                    Text(type.prettyString)
                                }
                            }
                        } label: {
                            Text(downwindManager.workoutType.prettyString)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .padding()
                    }
                    
                    
                        Text(tags.isEmpty ? "No Tags Active" : "Tracking Tags")
                    .fontWeight(.bold)
                    .padding(.bottom)
                        
                    TagsEditViewStatisticCapture(tags: $tags, downwindManager: downwindManager)
                            .padding(.horizontal)
                    
                    
                }
                
            
            
            
        } else {
            VStack {
                Button(role: .destructive) {
                    downwindManager.stopStatistic(onlyStatistic: onlyStatistics)
                } label: {
                    Label("Stop Tracking", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .padding()
                
                Text("Time: \(Text(downwindManager.activeRun.startedOn ?? Date.now, style: .timer))")
                    .monospacedDigit()
                
                let currentRunStatistic = downwindManager.runStatistics[downwindManager.currentRunStatisticIndex]
                
                Text("Distance: \(makePrettyDistance(meters: currentRunStatistic.runDistance, system: downwindManager.measurementSystem, statistics: true))")
                
                let averageSpeed = makePrettySpeed(speed: (currentRunStatistic.runDistance / 1000) / (currentRunStatistic.runTime / 60), system: downwindManager.measurementSystem)
                Text("Average Speed: \(averageSpeed)")
                
                Text("Top Speed: \(makePrettySpeed(speed: currentRunStatistic.topSpeed, system: downwindManager.measurementSystem))")
                Text("Accuracy of location: \(downwindManager.locationAccuracy) m")
                
                Spacer()
            }
            .frame(width: UIScreen.main.bounds.width / 1.2)
        }
        }

    }
}

#Preview {
    StatisticsControlCenter(downwindManager: DownwindManager())
}
