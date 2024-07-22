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
    var showAverageSpeed: Bool
    var selectedImage: UIImage?
    
    var body: some View {
        ZStack {
            if useMap {
                if let dW = statisticsData.workoutType?.isDWSport, dW == true {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: .constant(statisticsData))
                        .frame(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.width - 32)
                } else {
                    WindSportStatisticsMap(downwindManager: downwindManager, statisticsData: .constant(statisticsData))
                        .frame(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.width - 32)
                }
                    
            } else if let image = selectedImage {
                    
                Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.width - 32)
                
            } else {
                Image("Icon")
                    .resizable()
                    .frame(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.width - 32)
                    .aspectRatio(contentMode: .fill)
            }
            ShareOverlay(
                sport: statisticsData.workoutType?.prettyString ?? "Surfing",
                distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true),
                time: makePrettyTime(timeInMinutes: statisticsData.runTime),
                extraTitle: showAverageSpeed ? "∅-Speed" : "∅-Pace",
                extraValue: showAverageSpeed ?
                    makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) :
                    downwindManager.calculateAveragePace(statistic: statisticsData)
            )
            .frame(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.width - 32)
        }
    }
}

#Preview {
    ShareImagePreview(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: []), useMap: true, showAverageSpeed: true)
}
