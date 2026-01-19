//
//  GradientMapTestView.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import SwiftUI

struct GradientMapTestView: View {
    
    var statisticsData: RunStatistic
    
    var body: some View {
        SpeedGradientMapView(locations: statisticsData.locationData)
            .ignoresSafeArea()
    }
}

#Preview {
    GradientMapTestView(statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData))
}
