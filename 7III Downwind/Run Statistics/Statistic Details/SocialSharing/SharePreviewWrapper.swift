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
    var showAverageSpeed: Bool
    
    let onRendered: (UIView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let controller = UIHostingController(rootView: ShareImagePreview(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, showAverageSpeed: showAverageSpeed))
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.onRendered(controller.view)
        }
        return controller.view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        let controller = UIHostingController(rootView: ShareImagePreview(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showingSpeedInsteadPace: showingSpeedInsteadPace, showTopSpeed: showTopSpeed, showAverageSpeed: showAverageSpeed))
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
