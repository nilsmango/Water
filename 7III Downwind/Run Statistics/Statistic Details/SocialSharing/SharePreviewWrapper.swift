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
    var mapType: ShareMapType
    var gradientPoints: Double
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
    var fullScreen: Bool
    var showTags: Bool

    @Binding var offset: Double


    let onRendered: (UIView) -> Void


    func makeUIView(context: Context) -> UIView {
        context.coordinator.hostingController.rootView = AnyView(EmptyView())
        context.coordinator.updateRootView(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, mapType: mapType, gradientPoints: gradientPoints, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, topSpeedSelection: topSpeedSelection, showAverageSpeed: showAverageSpeed, scale: scale, locationName: locationName, showLocation: showLocation, showCalories: showCalories, showHeart: showHeartRate, showPopUps: showPopUps, showTimeOnFoil: showTimeOnFoil, showMaxDistanceOnFoil: showMaxDistanceOnFoil, showTurns: showTurns, fullScreen: fullScreen, showTags: showTags, offset: $offset)
        context.coordinator.hostingController.view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.onRendered(context.coordinator.hostingController.view)
        }
        return context.coordinator.hostingController.view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateRootView(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, mapType: mapType, gradientPoints: gradientPoints, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, topSpeedSelection: topSpeedSelection, showAverageSpeed: showAverageSpeed, scale: scale, locationName: locationName, showLocation: showLocation, showCalories: showCalories, showHeart: showHeartRate, showPopUps: showPopUps, showTimeOnFoil: showTimeOnFoil, showMaxDistanceOnFoil: showMaxDistanceOnFoil, showTurns: showTurns, fullScreen: fullScreen, showTags: showTags, offset: $offset)

        context.coordinator.hostingController.view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.onRendered(context.coordinator.hostingController.view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    struct MapSettings: Equatable {
        let useMap: Bool
        let mapType: ShareMapType
        let gradientPoints: Double
    }

    class Coordinator {
        let hostingController = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
        var lastMapSettings: MapSettings?

        func updateRootView(downwindManager: DownwindManager, statisticsData: RunStatistic, useMap: Bool, mapType: ShareMapType, gradientPoints: Double, showingSpeedInsteadPace: Bool, showTopSpeed: Bool, topSpeedSelection: TopSpeedOption, showAverageSpeed: Bool, scale: Double, locationName: String?, showLocation: Bool, showCalories: Bool, showHeart: Bool, showPopUps: Bool, showTimeOnFoil: Bool, showMaxDistanceOnFoil: Bool, showTurns: Bool, fullScreen: Bool, showTags: Bool, offset: Binding<Double>) {
            hostingController.rootView = AnyView(ShareImagePreview(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, mapType: mapType, gradientPoints: gradientPoints, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, topSpeedSelection: topSpeedSelection, showAverageSpeed: showAverageSpeed, scale: scale, locationName: locationName, showLocation: showLocation, showCalories: showCalories, showHeart: showHeart, showPopUps: showPopUps, showTimeOnFoil: showTimeOnFoil, showMaxDistanceOnFoil: showMaxDistanceOnFoil, showTurns: showTurns, fullScreen: fullScreen, showTags: showTags, offset: offset))
        }
    }
}

