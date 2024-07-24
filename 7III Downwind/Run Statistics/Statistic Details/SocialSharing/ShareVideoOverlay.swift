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
    var extraTitle: String
    var extraValue: String
    var topSpeedValue: String?
    var showAverageSpeed: Bool
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0.0) {

            
            Text("7III Water")
                .foregroundStyle(.white)
                .font(.title2)
                .fontWeight(.bold)
                .shadow(color: .black.opacity(0.4),radius: 5)
                .padding(.trailing, 16)
            
            HStack {
                
//                Spacer(minLength: 0.0)
                
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
                .padding(8)
                .foregroundStyle(.white)
            }
        }
        .frame(width: Constants.previewContainerWidth, height: Constants.previewContainerWidth * Constants.previewContainerHeightMultiple)
//        .frame(width: UIScreen.main.bounds.width)
    }
}

struct ShareVideoOverlay: View {
    var sport: String
    var distance: String
    var time: String
    var extraTitle: String
    var extraValue: String
    var topSpeedValue: String?
    var showAverageSpeed: Bool
    var scale: Double
    
    var body: some View {
        
            VideoOverlayContainer(
                sport: sport,
                distance: distance,
                time: time,
                extraTitle: extraTitle,
                extraValue: extraValue,
                topSpeedValue: topSpeedValue,
                showAverageSpeed: showAverageSpeed
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
        scale: 1
    )
    
//    .frame(width: 100)
//    .frame(width: 100, height: 540) // Example container size
}
