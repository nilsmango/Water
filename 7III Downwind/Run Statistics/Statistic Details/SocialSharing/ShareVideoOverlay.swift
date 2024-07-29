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
    var instagramReel: Bool
    
    var body: some View {
        let views: [AnyView] = [
            AnyView(
                Text("7III Water")
                    .foregroundStyle(.white)
                    .font(.title2)
                    .fontWeight(.bold)
                    .shadow(color: .black.opacity(0.4), radius: 5)
                    .padding(.trailing, 16)
            ),
            AnyView(
                HStack(alignment: .bottom) {
                    ShareStatStack(title: sport, value: distance)
                    Divider().frame(height: 35).background(.white)
                    ShareStatStack(title: timeTitle, value: time)
                    if showAverageSpeed {
                        Divider().frame(height: 35).background(.white)
                        ShareStatStack(title: extraTitle, value: extraValue)
                    }
                    if let topSpeed = topSpeedValue {
                        Divider().frame(height: 35).background(.white)
                        ShareStatStack(title: "Top Speed", value: topSpeed)
                    }
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 5).fill(.black).opacity(0.7)
                }
                .padding(8)
                .foregroundStyle(.white)
            )
        ]

        // Include the location HStack conditionally
        var conditionalViews = views
        if locationName != nil && locationName != "" && showLocation {
            conditionalViews.insert(
                AnyView(
                    HStack {
                        Image(systemName: "location.fill")
                        Text(locationName!)
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 5)
                    .padding(.trailing, 16)
                ), at: instagramReel ? 1 : 1
            )
        }

        let orderedViews = instagramReel ? conditionalViews.reversed() : conditionalViews

        return VStack(alignment: .trailing, spacing: 0.0) {
            ForEach(Array(orderedViews.enumerated()), id: \.offset) { _, view in
                view
            }
        }
        .frame(width: Constants.previewContainerWidth, height: Constants.previewContainerWidth * (showLocation && locationName != nil ? Constants.previewContainerHeightMultipleLocation : Constants.previewContainerHeightMultiple))
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
    var instagramReel: Bool
    
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
                locationName: locationName,
                instagramReel: instagramReel
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
        locationName: "Ipsach",
        instagramReel: true
    )
    .background(.blue)
    
//    .frame(width: 100)
//    .frame(width: 1000, height: 1080) // Example container size
}
