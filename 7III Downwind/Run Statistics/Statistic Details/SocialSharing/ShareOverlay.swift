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
    var topSpeedString: String
    var showAverageSpeed: Bool
    var locationName: String?
    var showLocation: Bool
    var caloriesTitle: String?
    var caloriesText: String
    var heartTitle: String?
    var heartText: String
    
    var popUpsTitle: String?
    var popUpsText: String
    var timeOnFoilTitle: String?
    var timeOnFoilText: String
    var maxDistanceOnFoilTitle: String?
    var maxDistanceOnFoilText: String
    var turnsTitle: String?
    var turnsText: String
    let fullScreen: Bool
    var tags: [String] = []
    var showTags: Bool = true
        
    var body: some View {
        VStack(alignment: fullScreen ? .center : .trailing, spacing: 0.0) {

                Text("7III Water")
                    .foregroundStyle(.white)
                    .font(fullScreen ? .title : .title2)
                    .fontWeight(.bold)
                    .shadow(color: .black.opacity(0.4),radius: 5)
                    .padding(.trailing, fullScreen ? 0 : 8)
                    .padding(.bottom, fullScreen ? 16 : 4)
                
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
                    .padding(.trailing, fullScreen ? 0 : 8)
                    .padding(.bottom, fullScreen ? 16 : 8)
                }
                
                if !tags.isEmpty && showTags {
                    HStack {
                        Text(tags.joined(separator: " "))
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4),radius: 5)
                    .padding(.trailing, fullScreen ? 0 : 8)
                    .padding(.bottom, fullScreen ? 16 : 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            HStack {
                
                HStack(alignment: .bottom) {
                                        
                    ShareStatStack(title: sport, value: distance)
                    
                    ShareOverlayDivider()
                    
                    ShareStatStack(title: "Time", value: time)
                    
                    if showAverageSpeed {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: extraTitle, value: extraValue)
                    }
                    
                    if let topSpeed = topSpeedValue {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: topSpeedString, value: topSpeed)
                    }
                    
                    if let popUpsTitle = popUpsTitle {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: popUpsTitle, value: popUpsText)
                    }
                    
                    if let timeOnFoilTitle = timeOnFoilTitle {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: timeOnFoilTitle, value: timeOnFoilText)
                    }
                    
                    if let maxDistanceOnFoilTitle = maxDistanceOnFoilTitle {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: maxDistanceOnFoilTitle, value: maxDistanceOnFoilText)
                    }
                    
                    if let turnsTitle = turnsTitle {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: turnsTitle, value: turnsText)
                    }
                    
                    if let caloriesTitle = caloriesTitle {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: caloriesTitle, value: caloriesText)
                    }
                    
                    if let heartTitle = heartTitle {
                        ShareOverlayDivider()
                        
                        ShareStatStack(title: heartTitle, value: heartText)
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
        
        VStack(alignment: .trailing) {
            Spacer()
            HStack {
                ShareOverlay(sport: "DW SUP Foil", distance: "12.4 km", time: "3:31", extraTitle: "∅-Pace", extraValue: "3:00 /km", topSpeedValue: "23 km/h",  topSpeedString: "10s Top Speed", showAverageSpeed: true, locationName: "Ipsach → Neuenburg", showLocation: true, caloriesTitle: "Calories", caloriesText: "23 kcal", heartTitle: "long her", heartText: "23", popUpsTitle: nil, popUpsText: "", timeOnFoilTitle: nil, timeOnFoilText: "", maxDistanceOnFoilText: "", turnsTitle: nil, turnsText: "", fullScreen: false, tags: ["#swim", "#wakeboard", "#fun"])
                    .scaleEffect(1, anchor: UnitPoint(x: 1, y: 1))
            }
            
        }
        .padding(8)
        
    }
    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
    
}
