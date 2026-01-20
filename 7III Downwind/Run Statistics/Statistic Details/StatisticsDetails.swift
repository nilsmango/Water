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
    let fastestKm: String?
    
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
                StatisticsInfoViews(header: "Pop-Ups", bodyText: String(popUps))
                    .frame(width: width, alignment: .leading)
                
                if turns != 0 {
                    StatisticsInfoViews(header: "Turns", bodyText: String(turns))
                        .frame(width: width, alignment: .leading)
                } else {
                    // we can use 0.0 km/h because we get that if speed is zero
                    if topSpeed != "0.0 km/h" {
                        StatisticsInfoViews(header: "GPS Top Speed", bodyText: topSpeed)
                            .frame(width: width, alignment: .leading)
                    }
                }
            }
        }
        
        if topSpeed != "0.0 km/h" || fastestKm != nil {
            HStack {
                
                if let fastestKm = fastestKm {
                    StatisticsInfoViews(header: "Fastest km", bodyText: fastestKm)
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
    }
}

#Preview {
    List {
        Section {
            StatisticsDetails(distance: "7.5 km", time: "23:30", averageSpeed: "13.4 km/h", averagePace: "2'23\" /km", topSpeed: "30.2 km/h", topsSpeed1s: "23.2 km/h", topsSpeed10s: "12.2 km/h", kCal: "84 kcal", heartRate: "120 bpm", popUps: 3, percentageOnFoil: 94.2, turns: 134, longestDistanceOnFoil: "15 km", fastestKm: "3:45 (km: 5.23)")
        }
    }
}
