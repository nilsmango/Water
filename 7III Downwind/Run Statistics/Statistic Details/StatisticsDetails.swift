//
//  StatisticsDetails.swift
//  7III Location
//
//  Created by Simon Lang on 08.04.2024.
//

import SwiftUI

struct StatisticsDetails: View {
    let distance: String
    let time: String
    let averageSpeed: String
    let averagePace: String
    let topSpeed: String
    let topsSpeed1s: String
    let topsSpeed10s: String
    let kCal: String
    let heartRate: String
    
    let popUps: Int
    let percentageOnFoil: Double
    let turns: Int
    let longestDistanceOnFoil: String
    let fastestDistances: [FastestDistanceResult]?
    let jumpCount: Int?
    let highestJump: String?
    let popUpsTitle: String
    let windRouteAnalysis: WindRouteAnalysis?
    let showsWindDirections: Bool
    let showsAutomaticAngles: Bool
    let measurementSystem: MeasurementSystem
    
    @Binding var hasTappedDistance: Bool
    
    init(
        distance: String,
        time: String,
        averageSpeed: String,
        averagePace: String,
        topSpeed: String,
        topsSpeed1s: String,
        topsSpeed10s: String,
        kCal: String,
        heartRate: String,
        popUps: Int,
        percentageOnFoil: Double,
        turns: Int,
        longestDistanceOnFoil: String,
        fastestDistances: [FastestDistanceResult]?,
        jumpCount: Int? = nil,
        highestJump: String? = nil,
        popUpsTitle: String = "Pop-Ups",
        windRouteAnalysis: WindRouteAnalysis? = nil,
        showsWindDirections: Bool = false,
        showsAutomaticAngles: Bool = false,
        measurementSystem: MeasurementSystem = .metric,
        hasTappedDistance: Binding<Bool>
    ) {
        self.distance = distance
        self.time = time
        self.averageSpeed = averageSpeed
        self.averagePace = averagePace
        self.topSpeed = topSpeed
        self.topsSpeed1s = topsSpeed1s
        self.topsSpeed10s = topsSpeed10s
        self.kCal = kCal
        self.heartRate = heartRate
        self.popUps = popUps
        self.percentageOnFoil = percentageOnFoil
        self.turns = turns
        self.longestDistanceOnFoil = longestDistanceOnFoil
        self.fastestDistances = fastestDistances
        self.jumpCount = jumpCount
        self.highestJump = highestJump
        self.popUpsTitle = popUpsTitle
        self.windRouteAnalysis = windRouteAnalysis
        self.showsWindDirections = showsWindDirections
        self.showsAutomaticAngles = showsAutomaticAngles
        self.measurementSystem = measurementSystem
        self._hasTappedDistance = hasTappedDistance
    }
    
    let width = UIScreen.main.bounds.width / 3
    var body: some View {
        
        HStack {
            StatisticsInfoViews(header: "Total Time", bodyText: time)
                .frame(width: width, alignment: .leading)
            if distance != "0 m" {
                StatisticsInfoViews(header: "Total Distance", bodyText: distance)
            }
        }

        if averagePace != " /km" && averagePace != "0'00\" /km" {
            HStack {
                StatisticsInfoViews(header: "∅-Pace", bodyText: averagePace)
                    .frame(width: width, alignment: .leading)
                StatisticsInfoViews(header: "∅-Speed", bodyText: averageSpeed)
            }
        }
        
        if percentageOnFoil != 0.0 && percentageOnFoil != .nan {
            HStack {
                StatisticsInfoViews(header: "Time On Foil", bodyText: String(format: "%.1f", percentageOnFoil) + " %")
                    .frame(width: width, alignment: .leading)
                
                StatisticsInfoViews(header: "Max Distance On Foil", bodyText: longestDistanceOnFoil)
                    .frame(width: width, alignment: .leading)
            }
            
            HStack {
                StatisticsInfoViews(header: popUpsTitle, bodyText: String(popUps))
                    .frame(width: width, alignment: .leading)
                
                if turns != 0 {
                    StatisticsInfoViews(header: "Turns", bodyText: String(turns))
                        .frame(width: width, alignment: .leading)
                }
            }
        }
        
        if topSpeed != "0.0 km/h" || (fastestDistances != nil && !fastestDistances!.isEmpty) {
            
            if let fastestDistances = fastestDistances, !fastestDistances.isEmpty {
                let shortDistances = fastestDistances.filter { $0.distanceLabel != "1 km" }
                
                if !shortDistances.isEmpty {
                    HStack {
                        ForEach(shortDistances.prefix(2), id: \.distanceLabel) { distance in
                            StatisticsInfoViewsInteractive(header: "Fastest \(distance.distanceLabel)", bodyText: distance.timeString, alternateText: distance.speedString, onTap: { hasTappedDistance = true })
                                .frame(width: width, alignment: .leading)
                        }
                    }
                }
            }
            
            HStack {
                if let fastestKm = fastestDistances?.first(where: { $0.distanceLabel == "1 km" }) {
                    StatisticsInfoViewsInteractive(header: "Fastest km", bodyText: fastestKm.timeString, alternateText: fastestKm.speedString, onTap: { hasTappedDistance = true })
                        .frame(width: width, alignment: .leading)
                }
                
                // we can use 0.0 km/h because we get that if speed is zero
                if topSpeed != "0.0 km/h" {
                    StatisticsInfoViews(header: "GPS Top Speed", bodyText: topSpeed)
                        .frame(width: width, alignment: .leading)
                }
            }
            
        }
         
        
        if topsSpeed10s != "0.0 km/h" {
            HStack {
                if topsSpeed1s != "0.0 km/h" {
                    StatisticsInfoViews(header: "1 Sec Top Speed ", bodyText: topsSpeed1s)
                        .frame(width: width, alignment: .leading)
                }
                
                StatisticsInfoViews(header: "10 Sec Top Speed ", bodyText: topsSpeed10s)
                    .frame(width: width, alignment: .leading)
            }
        }
        
        if jumpCount != nil || highestJump != nil {
            HStack {
                if let jumpCount {
                    StatisticsInfoViews(header: "Jumps", bodyText: String(jumpCount), headerBadgeText: "BETA")
                        .frame(width: width, alignment: .leading)
                }
                
                if let highestJump {
                    StatisticsInfoViews(header: "Highest Jump", bodyText: highestJump, headerBadgeText: "BETA")
                        .frame(width: width, alignment: .leading)
                }
            }
        }
        
        if heartRate != "0 bpm" || kCal != "0 kcal" {
            HStack {
                if heartRate != "0 bpm" {
                    StatisticsInfoViews(header: "∅-Heart Rate", bodyText: heartRate)
                            .frame(width: width, alignment: .leading)
                }
                
                if kCal != "0 kcal" {
                    StatisticsInfoViews(header: "Activity Calories", bodyText: kCal)
                        .frame(width: width, alignment: .leading)
                }
            }
        }

        if let windRouteAnalysis, showsWindDirections {
            HStack {
                StatisticsInfoViews(
                    header: "Upwind Distance",
                    bodyText: makePrettyDistance(meters: windRouteAnalysis.upwindDistance, system: measurementSystem, statistics: true)
                )
                .frame(width: width, alignment: .leading)

                StatisticsInfoViews(
                    header: "Downwind Distance",
                    bodyText: makePrettyDistance(meters: windRouteAnalysis.downwindDistance, system: measurementSystem, statistics: true)
                )
            }

            HStack {
                StatisticsInfoViews(
                    header: "Upwind Time",
                    bodyText: makePrettyTime(timeInMinutes: windRouteAnalysis.upwindDuration / 60)
                )
                .frame(width: width, alignment: .leading)

                StatisticsInfoViews(
                    header: "Downwind Time",
                    bodyText: makePrettyTime(timeInMinutes: windRouteAnalysis.downwindDuration / 60)
                )
            }

            HStack {
                StatisticsInfoViews(
                    header: "Idle Time",
                    bodyText: makePrettyTime(timeInMinutes: windRouteAnalysis.idleDuration / 60)
                )
                .frame(width: width, alignment: .leading)

                if let percentage = windRouteAnalysis.downwindToUpwindTimePercentage {
                    StatisticsInfoViews(
                        header: "Down / Up Time",
                        bodyText: String(format: "%.0f %%", percentage)
                    )
                }
            }
        }

        if let windRouteAnalysis,
           showsAutomaticAngles,
           let averageAngle = windRouteAnalysis.averageTurnAngle,
           let bestAngle = windRouteAnalysis.bestTurnAngle {
            HStack {
                StatisticsInfoViews(
                    header: "∅ Upwind Angle",
                    bodyText: String(format: "%.1f°", averageAngle)
                )
                .frame(width: width, alignment: .leading)

                StatisticsInfoViews(
                    header: "Best Upwind Angle",
                    bodyText: String(format: "%.1f°", bestAngle)
                )
            }
        }
    }
}

#Preview {
    List {
        Section {
            StatisticsDetails(distance: "7.5 km", time: "23:30", averageSpeed: "13.4 km/h", averagePace: "2'23\" /km", topSpeed: "30.2 km/h", topsSpeed1s: "23.2 km/h", topsSpeed10s: "12.2 km/h", kCal: "84 kcal", heartRate: "120 bpm", popUps: 3, percentageOnFoil: 94.2, turns: 134, longestDistanceOnFoil: "15 km", fastestDistances: [FastestDistanceResult(distanceLabel: "50 m", timeString: "7.1 s", speedString: "9.7 km/h", rawSpeed: 9.7), FastestDistanceResult(distanceLabel: "100 m", timeString: "14.2 s", speedString: "10.2 km/h", rawSpeed: 10.2), FastestDistanceResult(distanceLabel: "1 km", timeString: "3:45 min", speedString: "16.0 km/h", rawSpeed: 16.0)], jumpCount: 6, highestJump: "1.8 m", hasTappedDistance: .constant(false))
        }
    }
}
