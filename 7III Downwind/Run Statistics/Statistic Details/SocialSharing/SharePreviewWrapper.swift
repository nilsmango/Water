//
//  SharePreviewWrapper.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI

struct SharePreviewWrapper: UIViewRepresentable {
    var downwindManager: DownwindManager
    var statisticsData: RunStatistic
    var useMap: Bool
    var showingSpeedInsteadPace: Bool
    var showTopSpeed: Bool
    var topSpeedSelection: TopSpeedOption
    var showAverageSpeed: Bool
    var scale: Double
    var locationName: String?
    var showLocation: Bool
    var showCalories: Bool
    var showHeartRate: Bool
    var showPopUps: Bool
    var showTimeOnFoil: Bool
    var showMaxDistanceOnFoil: Bool
    var showTurns: Bool
    
    @Binding var offset: Double

    
    let onRendered: (UIView) -> Void
    
    
    func makeUIView(context: Context) -> UIView {
        let controller = UIHostingController(rootView: ShareImagePreview(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, topSpeedSelection: topSpeedSelection, showAverageSpeed: showAverageSpeed, scale: scale, locationName: locationName, showLocation: showLocation, showCalories: showCalories, showHeart: showHeartRate, showPopUps: showPopUps, showTimeOnFoil: showTimeOnFoil, showMaxDistanceOnFoil: showMaxDistanceOnFoil, showTurns: showTurns, offset: $offset))
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.onRendered(controller.view)
        }
        return controller.view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        let controller = UIHostingController(rootView: ShareImagePreview(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, topSpeedSelection: topSpeedSelection, showAverageSpeed: showAverageSpeed, scale: scale, locationName: locationName, showLocation: showLocation, showCalories: showCalories, showHeart: showHeartRate, showPopUps: showPopUps, showTimeOnFoil: showTimeOnFoil, showMaxDistanceOnFoil: showMaxDistanceOnFoil, showTurns: showTurns, offset: $offset))
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.onRendered(controller.view)
        }
        uiView.subviews.forEach { $0.removeFromSuperview() }
        uiView.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: uiView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
        ])
    }
}
