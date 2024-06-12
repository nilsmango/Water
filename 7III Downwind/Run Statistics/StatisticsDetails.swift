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
    let kCal: String
    let heartRate: String
    
    let width = UIScreen.main.bounds.width / 3
    var body: some View {
        
        HStack {
            StatisticsInfoViews(header: "Total Time", bodyText: time)
                .frame(width: width, alignment: .leading)
            if distance != "0 m" {
                StatisticsInfoViews(header: "Total Distance", bodyText: distance)
            }
        }
        
        if averagePace != " /km" {
            HStack {
                StatisticsInfoViews(header: "∅-Pace", bodyText: averagePace)
                    .frame(width: width, alignment: .leading)
                StatisticsInfoViews(header: "∅-Speed", bodyText: averageSpeed)
            }
        }
        
        HStack {
            if topSpeed != "0.0 km/h" {
                StatisticsInfoViews(header: "Top Speed", bodyText: topSpeed)
                    .frame(width: width, alignment: .leading)
            }
            if kCal != "0 kcal" {
                StatisticsInfoViews(header: "Activity Calories", bodyText: kCal)
            }
        }
        
        if heartRate != "0 bpm" {
            HStack {
                StatisticsInfoViews(header: "∅-Heart Rate", bodyText: heartRate)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}

#Preview {
    List {
        Section {
            StatisticsDetails(distance: "7.5 km", time: "23:30", averageSpeed: "13.4 km/h", averagePace: "2'23\" /km", topSpeed: "30.2 km/h", kCal: "84 kcal", heartRate: "120 bpm")
        }
    }
}
