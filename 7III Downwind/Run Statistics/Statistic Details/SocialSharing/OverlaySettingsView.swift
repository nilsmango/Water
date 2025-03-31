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
    @Binding var showTurns: Bool
    @Binding var showCalories: Bool
    @Binding var showHeartRate: Bool
    @Binding var useMap: Bool
    @Binding var showImagePicker: Bool
    @Binding var showCamera: Bool
    
    var statisticsData: RunStatistic
    
    var body: some View {
        Group {
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
                    
                    
                        
                    if statisticsData.workoutType?.countFalls ?? false || statisticsData.workoutType?.countWaves ?? false {
                        Toggle("Show Pop Ups", isOn: $showPopUps)
                            .tint(.accent)
                    }
                    
                    if statisticsData.percentageOnFoil != 0 {
                        Toggle("Show Time On Foil", isOn: $showTimeOnFoil)
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
