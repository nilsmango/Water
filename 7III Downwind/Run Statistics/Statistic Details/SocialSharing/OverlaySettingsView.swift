//
//  OverlaySettingsView.swift
//  7III Tracker
//
//  Created by Simon Lang on 21.02.2025.
//

import SwiftUI

struct OverlaySettingsView: View {
    @Binding var scale: Double
    @Binding var showLocation: Bool
    @Binding var showAverageSpeed: Bool
    @Binding var speedSelection: SpeedOption
    @Binding var showTopSpeed: Bool
    @Binding var topSpeedSelection: TopSpeedOption
    @Binding var showPopUps: Bool
    @Binding var showTimeOnFoil: Bool
    @Binding var showMaxDistanceOnFoil: Bool
    @Binding var showTurns: Bool
    @Binding var showCalories: Bool
    @Binding var showHeartRate: Bool
    @Binding var showTags: Bool
    @Binding var useMap: Bool
    @Binding var mapType: ShareMapType
    @Binding var gradientPoints: Double
    @Binding var showImagePicker: Bool
    @Binding var showCamera: Bool
//    @Binding var fullScreen: Bool

    var statisticsData: RunStatistic

    var availableMapTypes: [ShareMapType] {
        if statisticsData.workoutType?.isDWSport == true {
            return ShareMapType.allCases
        } else {
            return [.gradient, .yellow]
        }
    }

    var body: some View {
        Group {
//            Toggle("Insta Story", isOn: $fullScreen)
//                .tint(.accent)
            //                    Toggle("Use Map", isOn: $useMap)
            Stepper(value: $scale, in: 0.5...1.0, step: 0.1) {
                HStack {
                    Text("Overlay Scale")
                    Spacer()
                    Text("\(scale, specifier: "%.1f")")
                        .monospacedDigit()
                }
            }
            Toggle("Show Location", isOn: $showLocation)
                .tint(.accent)
            
            if statisticsData.tags != nil && !statisticsData.tags!.isEmpty {
                Toggle("Show Tags", isOn: $showTags)
                    .tint(.accent)
            }

            if useMap {
                Picker("Map Type", selection: $mapType) {
                    ForEach(availableMapTypes, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if mapType == .gradient {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Max Points")
                            Spacer()
                            Text("\(Int(gradientPoints))")
                                .monospacedDigit()
                        }
                        Slider(value: $gradientPoints, in: 1000...3000, step: 100)
                        Text("More points = smoother route, heavier rendering")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
                
                let hasDistance = statisticsData.runDistance > 0
                
                if hasDistance {
                    
                    Toggle("Show \(speedSelection.rawValue)", isOn: $showAverageSpeed)
                        .tint(.accent)
                    if showAverageSpeed {
                        Picker("∅-Speed Format", selection: $speedSelection) {
                            ForEach(SpeedOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Toggle("Show Top Speed", isOn: $showTopSpeed)
                        .tint(.accent)
                    
                    if showTopSpeed {
                        Picker("∅-Speed Format", selection: $topSpeedSelection) {
                            ForEach(TopSpeedOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    
                    if statisticsData.workoutType?.calculateFoilingStats ?? false {
                        Toggle("Show Pop Ups", isOn: $showPopUps)
                            .tint(.accent)
                    }
                    
                    if statisticsData.percentageOnFoil != nil && statisticsData.percentageOnFoil != 0 {
                        Toggle("Show Time On Foil", isOn: $showTimeOnFoil)
                            .tint(.accent)
                    }
                    
                    if statisticsData.longestDistanceOnFoil != 0 && statisticsData.longestDistanceOnFoil != nil {
                        Toggle("Show Longest Flight", isOn: $showMaxDistanceOnFoil)
                            .tint(.accent)
                    }
                    
                    if statisticsData.workoutType?.isDWSport ?? false {
                        Toggle("Show Turns", isOn: $showTurns)
                            .tint(.accent)
                    }
                    
                    Toggle("Show Calories", isOn: $showCalories)
                        .tint(.accent)
                    Toggle("Show ∅-Heart Rate", isOn: $showHeartRate)
                        .tint(.accent)
                }
            
            
            if !useMap {
                HStack {
                    Button("Choose Photo") {
                        showImagePicker = true
                    }
                    Spacer()
                    Button("Take Photo") {
                        showCamera = true
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }
}

//
//#Preview {
//    OverlaySettingsView(scale: <#Binding<Double>#>, showLocation: <#Binding<Bool>#>, showAverageSpeed: <#Binding<Bool>#>, speedSelection: <#Binding<SpeedOption>#>, showTopSpeed: <#Binding<Bool>#>, topSpeedSelection: <#Binding<TopSpeedOption>#>, showPopUps: <#Binding<Bool>#>, showTimeOnFoil: <#Binding<Bool>#>, showTurns: <#Binding<Bool>#>, showCalories: <#Binding<Bool>#>, showHeartRate: <#Binding<Bool>#>, useMap: <#Binding<Bool>#>, showImagePicker: <#Binding<Bool>#>, showCamera: <#Binding<Bool>#>, statisticsData: <#RunStatistic#>)
//}
