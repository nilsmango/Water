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
    
    let width = UIScreen.main.bounds.width / 3
    var body: some View {
            
        HStack {
                StatisticsInfoViews(header: "Total Time", bodyText: time)
                .frame(width: width, alignment: .leading)
                StatisticsInfoViews(header: "Total Distance", bodyText: distance)
            }
                
        HStack {
            StatisticsInfoViews(header: "∅-Pace", bodyText: averagePace)
                .frame(width: width, alignment: .leading)
            StatisticsInfoViews(header: "∅-Speed", bodyText: averageSpeed)
        }
        
        HStack {
            StatisticsInfoViews(header: "Top Speed", bodyText: topSpeed)
                .frame(width: width, alignment: .leading)

        }
            }
        }

#Preview {
    List {
        Section {
            StatisticsDetails(distance: "7.5 km", time: "23:30", averageSpeed: "13.4 km/h", averagePace: "2'23\" /km", topSpeed: "30.2 km/h")
        }
    }
}
