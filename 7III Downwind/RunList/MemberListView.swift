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
    
    let screenWidth = UIScreen.main.bounds.width
    
    @State private var showLastUpdate = false
    
    var body: some View {
        VStack {
            HStack {
                Text(member.name)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if distance != nil {
                    Group {
                        BearingArrowView(degrees: degrees)
    //                        .padding(.trailing, 3)
                        
                        Text(makePrettyDistance(meters: distance!, system: measurementSystem))
                            .fontWeight(.bold)
                    }

                    Group {
                        if let speed = member.speed {
                            Text(makePrettySpeed(speed: speed, system: measurementSystem))
                        } else {
                            Text(measurementSystem == .imperial ? "- mph" : "- km/h")
                        }
                    }
                    .frame(maxWidth: screenWidth/5, alignment: .trailing)
                    
                } else {
                    Text("No Data")
                    
                    Text(measurementSystem == .imperial ? "- mph" : "- km/h")
                        .frame(maxWidth: screenWidth/5, alignment: .trailing)
                }
            }
            .padding(.bottom, showDetail ? 3 : 0)
            
            if showDetail {
                
                    HStack {
                        if showLastUpdate {
                            if let dateString = member.lastUpdated {
                                let date = dateFromString(dateString)
                                Text("Last updated: \(Text(date!, style: .timer))")
                                    .monospacedDigit()
                            } else {
                                Text("Last updated: unknown")
                            }
                            
                            Spacer()
                            
                        } else {

                        if let status = member.status {
                            Text(status)
                        }
                        
                        Spacer()
                        
                        if let latitude = member.latitude, let longitude = member.longitude {
                            Text("\(latitude), \(longitude)")
                        }
                        
                    }
                }
                
            }
            
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showLastUpdate.toggle()
        }
        .onLongPressGesture {
            // TODO: either copy location coordinates and last updated or show share thing for that
            print("copy that stuff here")
        }
    }
}

#Preview {
    List {
        MemberListView(member: Member(id: UUID(), name: "Lay Kenny", status: "🥶🥶🥶", latitude: 47.127145, longitude: 7.220062, speed: 15.3, lastUpdated: "2024-01-21T13:36:12Z"), distance: 200.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
        MemberListView(member: Member(id: UUID(), name: "Mister Bennetts", status: "Foil Flow", latitude: 47.127165, longitude: 7.2200672, speed: 15.3), distance: 20.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
        MemberListView(member: Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.127165, longitude: 7.2200672, speed: 1.3), distance: 4000.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
    }
}
