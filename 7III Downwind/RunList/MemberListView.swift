//
//  MemberListView.swift
//  7III Downwind
//
//  Created by Simon Lang on 18.01.2024.
//

import SwiftUI

struct MemberListView: View {
    let member: Member
    let distance: Double?
    
    let degrees: Double
    
    let measurementSystem: MeasurementSystem
    
    let showDetail: Bool
    
    var body: some View {
        VStack {
            HStack {
                Text(member.name)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if distance != nil {
                    BearingArrowView(degrees: degrees)
                        .padding(.trailing, 5)
                    
                    Text(makePrettyDistance(meters: distance!, system: measurementSystem))
                        .fontWeight(.bold)

                    Group {
                        if let speed = member.speed {
                            Text(makePrettySpeed(speed: speed, system: measurementSystem))
                        } else {
                            Text(measurementSystem == .imperial ? "- mph" : "- km/h")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                } else {
                    Text("No Data")
                    
                    Text(measurementSystem == .imperial ? "- mph" : "- km/h")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.bottom, showDetail ? 3 : 0)
            
            if showDetail {
                HStack {
                    if let status = member.status {
                        Text(status)
                    }
                    
                    Spacer()
                    
                    if let latitude = member.latitude, let longitude = member.longitude {
                        Text("\(latitude), \(longitude)")
                            .textSelection(.enabled)
                    }
                    
                }
            }
            
        }
    }
}

#Preview {
    List {
        MemberListView(member: Member(id: UUID(), name: "Lay Kenny", status: "🥶🥶🥶", latitude: 47.127145, longitude: 7.220062, speed: 15.3), distance: 200.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
        MemberListView(member: Member(id: UUID(), name: "Hardly Rippi", status: "Every Man For Himself", latitude: 47.127165, longitude: 7.2200672, speed: 15.3), distance: 400.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
        MemberListView(member: Member(id: UUID(), name: "Nils Mango", status: "Broke Paddle, but A-OK", latitude: 47.127165, longitude: 7.2200672, speed: 15.3), distance: 400.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
    }
}
