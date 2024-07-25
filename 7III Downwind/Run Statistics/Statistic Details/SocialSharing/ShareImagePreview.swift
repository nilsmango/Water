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
    var selectedImage: UIImage?
    var showAverageSpeed: Bool
    var scale: Double
    var locationName: String?
    var showLocation: Bool
    
    var body: some View {
        ZStack {
            if useMap {
                if let dW = statisticsData.workoutType?.isDWSport, dW == true {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: .constant(statisticsData))
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                } else {
                    WindSportStatisticsMap(downwindManager: downwindManager, statisticsData: .constant(statisticsData))
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                }
                    
            } else if let image = selectedImage {
                    
                Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                
            } else {
                Image("Icon")
                    .resizable()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .aspectRatio(contentMode: .fill)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ShareOverlay(
                        sport: statisticsData.workoutType?.prettyString ?? "Surfing",
                        distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true),
                        time: makePrettyTime(timeInMinutes: statisticsData.runTime),
                        extraTitle: showingSpeedInsteadPace ? "∅-Speed" : "∅-Pace",
                        extraValue: showingSpeedInsteadPace ?
                            makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) :
                            downwindManager.calculateAveragePace(statistic: statisticsData),
                        topSpeedValue: showTopSpeed ? makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem) : nil,
                        showAverageSpeed: showAverageSpeed, 
                        locationName: locationName,
                        showLocation: showLocation
                    )
                    .scaleEffect(scale, anchor: UnitPoint(x: 1, y: 1))
                }
                
            }
            .padding(8)
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
            
        }
    }
}

#Preview {
    ShareImagePreview(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: []), useMap: true, showingSpeedInsteadPace: true, showTopSpeed: true, showAverageSpeed: true, scale: 1, locationName: "Ipsach", showLocation: true)
}
