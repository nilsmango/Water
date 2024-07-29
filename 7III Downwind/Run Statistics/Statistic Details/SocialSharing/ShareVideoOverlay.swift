//
//  ShareVideoOverlay.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI
import MapKit

struct VideoOverlayContainer: View {
    var sport: String
    var distance: String
    var time: String
    var timeTitle: String
    var extraTitle: String
    var extraValue: String
    var topSpeedValue: String?
    var showAverageSpeed: Bool
    var showLocation: Bool
    var locationName: String?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0.0) {

            
            Text("7III Water")
                .foregroundStyle(.white)
                .font(.title2)
                .fontWeight(.bold)
                .shadow(color: .black.opacity(0.4),radius: 5)
                .padding(.trailing, 16)
            
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
                .padding(.trailing, 16)
//                .padding(.bottom, 4)
            }
            
            HStack {
                
//                Spacer(minLength: 0.0)
                
                HStack(alignment: .bottom) {
                                        
                    ShareStatStack(title: sport, value: distance)
                    
                    Divider()
                        .frame(height: 35)
                        .background(.white)
                    
                    ShareStatStack(title: timeTitle, value: time)
                    
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
                .padding(8)
                .foregroundStyle(.white)
            }
        }
        .frame(width: Constants.previewContainerWidth, height: Constants.previewContainerWidth * (showLocation && locationName != nil ? Constants.previewContainerHeightMultipleLocation : Constants.previewContainerHeightMultiple))
//        .frame(width: UIScreen.main.bounds.width)
    }
}

struct ShareVideoOverlay: View {
    var sport: String
    var distance: String
    var time: String
    var timeTitle: String = "Time"
    var extraTitle: String
    var extraValue: String
    var topSpeedValue: String?
    var showAverageSpeed: Bool
    var scale: Double
    var showLocation: Bool
    var locationName: String?
    
    var body: some View {
        
            VideoOverlayContainer(
                sport: sport,
                distance: distance,
                time: time,
                timeTitle: timeTitle,
                extraTitle: extraTitle,
                extraValue: extraValue,
                topSpeedValue: topSpeedValue,
                showAverageSpeed: showAverageSpeed,
                showLocation: showLocation,
                locationName: locationName
            )
            .scaleEffect(scale)
         
    }
}

#Preview {
    ShareVideoOverlay(
        sport: "DW SUP Foil",
        distance: "12.4 km",
        time: "3:31",
        extraTitle: "∅-Pace",
        extraValue: "3:00 /km",
        topSpeedValue: "23 km/h",
        showAverageSpeed: true,
        scale: 1,
        showLocation: true,
        locationName: "Ipsach"
    )
    .background(.blue)
    
//    .frame(width: 100)
//    .frame(width: 1000, height: 1080) // Example container size
}
