//
//  SharePreview.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI

struct ShareImagePreview: View {
    @ObservedObject var downwindManager: DownwindManager
    var statisticsData: RunStatistic
    var useMap: Bool
    var showingSpeedInsteadPace: Bool
    var showTopSpeed: Bool
    var topSpeedSelection: TopSpeedOption
    var selectedImage: UIImage?
    var showAverageSpeed: Bool
    var scale: Double
    var locationName: String?
    var showLocation: Bool
    var showCalories: Bool
    var showHeart: Bool
    var showPopUps: Bool
    var showTimeOnFoil: Bool
    var showMaxDistanceOnFoil: Bool
    var showTurns: Bool
    var fullScreen: Bool
    
    @Binding var offset: Double
    
    var body: some View {
        ZStack {
            if useMap {
                if let dW = statisticsData.workoutType?.isDWSport, dW == true {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: .constant(statisticsData))
                        .frame(width: UIScreen.main.bounds.width, height: fullScreen ? UIScreen.main.bounds.width * 1.7777777777777777 : UIScreen.main.bounds.width)
                        .allowsHitTesting(!fullScreen)
                } else {
                    WindSportStatisticsMap(downwindManager: downwindManager, statisticsData: .constant(statisticsData))
                        .frame(width: UIScreen.main.bounds.width, height: fullScreen ? UIScreen.main.bounds.width * 1.7777777777777777 : UIScreen.main.bounds.width)
                        .allowsHitTesting(!fullScreen)
                }
                    
            } else if let image = selectedImage {
                    
                Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIScreen.main.bounds.width, height: fullScreen ? UIScreen.main.bounds.width * 1.25 : UIScreen.main.bounds.width)
                
            } else {
                Image("Icon")
                    .resizable()
                    .frame(width: UIScreen.main.bounds.width, height: fullScreen ? UIScreen.main.bounds.width * 1.7777777777777777 : UIScreen.main.bounds.width)
                    .aspectRatio(contentMode: .fill)
            }
            VStack {
                    Spacer()
                
                HStack {
                    
                    if !fullScreen {
                        Spacer(minLength: 0.0)
                    }
                    
                    Group {
                        let hasDistance = statisticsData.runDistance > 0
                                                
                        let topSpeedValue = getTopSpeedValue()
                        
                        let topSpeedString = topSpeedSelection.rawValue
                        
                        ShareOverlay(
                            sport: statisticsData.workoutType?.prettyString ?? "Surfing",
                            distance: hasDistance ? makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true) : String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal",
                            time: makePrettyTime(timeInMinutes: statisticsData.runTime),
                            extraTitle: hasDistance ? showingSpeedInsteadPace ? "∅-Speed" : "∅-Pace" : "∅-Heart Rate",
                            extraValue: hasDistance ? showingSpeedInsteadPace ?
                                makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) :
                                downwindManager.calculateAveragePace(statistic: statisticsData) : String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm",
                            topSpeedValue: hasDistance ? showTopSpeed ? topSpeedValue : nil : nil,
                            topSpeedString: topSpeedString,
                            showAverageSpeed: hasDistance ? showAverageSpeed : true,
                            locationName: locationName,
                            showLocation: showLocation,
                            caloriesTitle: showCalories ? "Calories" : nil,
                            caloriesText: String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal",
                            heartTitle: showHeart ? "∅-Heart Rate" : nil,
                            heartText: String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm",
                            popUpsTitle: showPopUps ? "Pop Ups" : nil,
                            popUpsText: String(statisticsData.popUps ?? 0),
                            timeOnFoilTitle: showTimeOnFoil ? "Time On Foil" : nil,
                            timeOnFoilText: String(format: "%.1f", statisticsData.percentageOnFoil ?? 0) + " %",
                            maxDistanceOnFoilTitle: showMaxDistanceOnFoil ? "Longest Flight" : nil,
                            maxDistanceOnFoilText:  String(format: "%.1f", (statisticsData.longestDistanceOnFoil ?? 0) / 1000) +  " km",
                            turnsTitle: showTurns ? "Turns" : nil,
                            turnsText: String(statisticsData.turnsCount ?? 0),
                            fullScreen: fullScreen
                        )
                        .scaleEffect(scale, anchor: fullScreen ? UnitPoint(x: 0.5, y: 1) : UnitPoint(x: 1, y: 1))

                    }
                    
                }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                if !fullScreen {
                                    let sizeDifference = (geo.size.width - (UIScreen.main.bounds.width)) / 2
                                    if sizeDifference >= 0 {
                                        offset = -sizeDifference + -8.0
                                    } else {
                                        offset = -8.0
                                    }
                                }
                                
                            }
                    }
                }
                .offset(CGSize(width: offset, height: 0))
                
                
            }
            .padding(.bottom, fullScreen ? 32 : 8)
            .frame(width: UIScreen.main.bounds.width, height: fullScreen ? UIScreen.main.bounds.width * 1.7777777777777777 : UIScreen.main.bounds.width)
        }
    }
    
    private func getTopSpeedValue() -> String {
        switch topSpeedSelection {
        case .gps:
            return makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem)
        case .top1:
            return makePrettySpeed(speed: statisticsData.topSpeed1s, system: downwindManager.measurementSystem)
        case .top10:
            return makePrettySpeed(speed: statisticsData.topSpeed10s, system: downwindManager.measurementSystem)
        }
    }
}



#Preview {
    ShareImagePreview(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: []), useMap: true, showingSpeedInsteadPace: true, showTopSpeed: true, topSpeedSelection: .top1, showAverageSpeed: true, scale: 1.0, locationName: "Ipsach", showLocation: true, showCalories: true, showHeart: true, showPopUps: true, showTimeOnFoil: true, showMaxDistanceOnFoil: true, showTurns: true, fullScreen: true, offset: .constant(-8.0))
}
