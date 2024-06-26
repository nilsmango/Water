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
    @State private var showAlert = false
    
    var body: some View {
        VStack {
            HStack {
                Text(member.name)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if distance != nil {
                    Group {
                        BearingArrowView(degrees: degrees)
                        
                        Text(makePrettyDistance(meters: distance!, system: measurementSystem))
                            .fontWeight(.bold)
                    }
                }
                
                Group {
                    if let speed = member.speed {
                        Text(makePrettySpeed(speed: speed * 3.6, system: measurementSystem))
                    } else {
                        Text(measurementSystem == .imperial ? "- mph" : "- km/h")
                    }
                }
                .frame(maxWidth: screenWidth/5, alignment: .trailing)
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

                        Text(member.status ?? "")
                        
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
            if let latitude = member.latitude, let longitude = member.longitude {
                UIPasteboard.general.string = "\(latitude), \(longitude)"
                showAlert = true
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: Constants.updateTimer, repeats: true) { _ in
                showLastUpdate.toggle()
            }
        }
        .overlay {
            OverlayAlertView(showAlert: $showAlert, text: "Coordinates copied!", symbolPositive: true, padding: 10.0)
        }
    }
}

#Preview {
    List {
        MemberListView(member: Member(id: UUID(), name: "Lay Kenny", status: "🥶🥶🥶", latitude: 47.127145, longitude: 7.220062, speed: 15.3, lastUpdated: "2024-01-21T13:36:12Z"), distance: 7.3, degrees: 172, measurementSystem: .metric, showDetail: true)
        
        MemberListView(member: Member(id: UUID(), name: "James Casey", status: "Foil Flow", latitude: 47.127165, longitude: 7.2200672, speed: 24.3), distance: 210.0, degrees: 210, measurementSystem: .metric, showDetail: true)
        
        MemberListView(member: Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.127165, longitude: 7.2200672, speed: 31.3), distance: 4000.0, degrees: 23, measurementSystem: .metric, showDetail: true)
        
    }
}
