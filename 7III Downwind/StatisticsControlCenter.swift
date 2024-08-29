//
//  StatisticsControlCenter.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI
import StoreKit

struct StatisticsControlCenter: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var tags = [String]()
    
    @State private var showTagsEditView = false
    
    let width = UIScreen.main.bounds.width / 4
    
    var body: some View {
        VStack {
            if downwindManager.activeStatistics == false {
                VStack {
                    if downwindManager.hasHealthActivated {
                        HStack {
                            Button {
                                downwindManager.checkHealthKitAuthorizationStatus()
                                if downwindManager.hasHealthActivated {
                                    downwindManager.startStatistic(tags: tags)
                                }
                            } label: {
                                Label("Start Tracking", systemImage: "play")
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                            .padding(.trailing)
                            
                            Menu {
                                ForEach(WorkoutType.allCases.sorted(by: {
                                    (downwindManager.workoutUsageCount[$0] ?? 0) > (downwindManager.workoutUsageCount[$1] ?? 0)
                                }), id: \.self) { type in
                                    if type != .not7IIIPaddleSport && type != .not7IIISurfingSport {
                                        Button(action: {
                                            downwindManager.workoutType = type
                                        }) {
                                            if downwindManager.workoutType == type {
                                                Label(type.prettyString, systemImage: "checkmark")
                                            } else {
                                                Text(type.prettyString)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Text(downwindManager.workoutType.prettyString)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        .padding()
                        
                        TagsEditViewStatisticCapture(tags: $tags, downwindManager: downwindManager)
                            .padding(.horizontal)
                            .padding(.bottom)
                    } else {
                        HStack {
                            Spacer()
                            VStack {
                                Text("To track and save your sessions, please enable Health data access for 7III Water.")
                                    .padding(.bottom)
                                
                                Text("**Instructions**\n1. Open the Settings app\n2. Tap 'Privacy & Security'\n3. Tap 'Health'\n4. Find and tap '7III Water'\n5. Activate all permissions")

                                        .font(.callout)
                                    .padding()
                                    .background {
                                       RoundedRectangle(cornerRadius: 8)
                                            .fill(.accent.opacity(0.2))
                                    }
                            }
                            Spacer()
                        }
                        
                        .padding()
                        
                        Button(action: {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                                   UIApplication.shared.canOpenURL(settingsUrl) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                        }, label: {
                            Label("Open Settings", systemImage: "gear")
                        })
                        .buttonStyle(.bordered)
//                        .tint(.accent)
                        .padding(.bottom)
                    }
                }
                .background {
                    ListBackground()
                }
                
            } else {
                VStack {
                    Button(role: .destructive) {
                        downwindManager.stopStatistic()
                    } label: {
                        Label("End Tracking", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    
                    let currentRunStatistic = downwindManager.runStatistics[downwindManager.currentRunStatisticIndex]
                    
                    let averageSpeed = makePrettySpeed(speed: (currentRunStatistic.runDistance / 1000) / (currentRunStatistic.runTime / 60), system: downwindManager.measurementSystem)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Time")
                                .font(.caption)
                            
                            Text(currentRunStatistic.startDate ?? Date.now, style: .timer)
                                .monospacedDigit()
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .frame(width: width, alignment: .leading)
                        
                        VStack(alignment: .leading) {
                            Text("Total Distance")
                                .font(.caption)
                            
                            Text(makePrettyDistance(meters: currentRunStatistic.runDistance, system: downwindManager.measurementSystem, statistics: true))
                                .monospacedDigit()
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .frame(width: width, alignment: .leading)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("∅-Speed")
                                .font(.caption)
                            
                            Text(averageSpeed)
                                .monospacedDigit()
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .frame(width: width, alignment: .leading)
                        
                        VStack(alignment: .leading) {
                            Text("Top Speed")
                                .font(.caption)
                            
                            Text(makePrettySpeed(speed: currentRunStatistic.topSpeed, system: downwindManager.measurementSystem))
                                .monospacedDigit()
                                .font(.body)
                                .foregroundColor(.primary)
                            
                        }
                        .frame(width: width, alignment: .leading)
                    }
                    .padding(.bottom, 8)
                    .padding(.top, 6)
                    
                    HStack {
                        Spacer()
                    }
                    .frame(height: 0.0)
                    
                    //                Text("Accuracy of location: \(downwindManager.locationAccuracy) m")
                    
                }
                .background {
                    ListBackground()
                }
            }
        }
    }
}

struct ListBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10.0)
            .fill(.listForeground)
    }
}

#Preview {
    VStack {
        StatisticsControlCenter(downwindManager: DownwindManager())
            .padding()
        Spacer()
    }
        .background {
            Rectangle()
                .ignoresSafeArea()
                .foregroundStyle(.listBackground)
        }
}
