//
//  ShareOverlay.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI
import MapKit

struct ShareOverlay: View {
    var sport: String
    var distance: String
    var time: String
    var extraTitle: String
    var extraValue: String
    var topSpeedValue: String?
    var showAverageSpeed: Bool
    var locationName: String?
    var showLocation: Bool
    
    var body: some View {
        Group {
            
        }
        VStack(alignment: .trailing, spacing: 0.0) {

                Text("7III Water")
                    .foregroundStyle(.white)
                    .font(.title2)
                    .fontWeight(.bold)
                    .shadow(color: .black.opacity(0.4),radius: 5)
                    .padding(.trailing, 8)
                
                if locationName != nil && locationName != "" && showLocation {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(locationName!)
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4),radius: 5)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
            
            
            HStack {
                
                HStack(alignment: .bottom) {
                                        
                    ShareStatStack(title: sport, value: distance)
                    
                    Divider()
                        .frame(height: 35)
                        .background(.white)
                    
                    ShareStatStack(title: "Time", value: time)
                    
                    if showAverageSpeed {
                        Divider()
                            .frame(height: 35)
                            .background(.white)
                        
                        ShareStatStack(title: extraTitle, value: extraValue)
                    }
                    
                    if let topSpeed = topSpeedValue {
                        Divider()
                            .frame(height: 35)
                            .background(.white)
                        
                        ShareStatStack(title: "Top Speed", value: topSpeed)
                    }
                        
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.black)
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ZStack {
        Map()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                ShareOverlay(sport: "DW SUP Foil", distance: "12.4 km", time: "3:31", extraTitle: "∅-Pace", extraValue: "3:00 /km", topSpeedValue: "23 km/h", showAverageSpeed: true, locationName: "Ipsach → Neuenburg", showLocation: true)
                    .scaleEffect(1, anchor: UnitPoint(x: 1, y: 1))
            }
            .padding(8)
        }
        
        
    }
    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
    
}
