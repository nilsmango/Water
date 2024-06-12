//
//  RunOverView.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

struct RunOverView: View {
    let runDate: String
    let runName: String
    let distance: String
    let time: String
    let averageSpeed: String
    let kCal: String
    let activityType: String
    
    var body: some View {
        VStack {
            HStack {
                Text(runDate)
                    .fontWeight(.bold)
                Text(activityType)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.accent)
                Spacer()
            }
            
            if distance != "0 m" {
            HStack {
                    Text(distance)
                    Text(time)
                    if averageSpeed != "0.0 km/h" {
                        Text("∅ " + averageSpeed)
                    }
                    
                    Spacer()
                }
                if kCal != "0 kcal" {
                    HStack {
                        Text(kCal)
                        Spacer()
                    }
                }
                
            } else {
                HStack {
                    Text(time)
                    if averageSpeed != "0.0 km/h" {
                        Text("∅ " + averageSpeed)
                    }
                    if kCal != "0 kcal" {
                        Text(kCal)
                    }
                    Spacer()
                }
            }
            
        }
    }
}

#Preview {
    NavigationStack {
        List {
            NavigationLink {
                Text("Run run run")
            } label: {
                RunOverView(runDate: "Jan 03 20:30 - 23:00", runName: "Flying Eagles Club", distance: "21 km", time: "43 min 12 s", averageSpeed: "15 km/h", kCal: "1083 kcal", activityType: "DW SUP Foil")
            }
        }
        
    }
    
    
}
