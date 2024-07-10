//
//  YearlyStatisticView.swift
//  7III Tracker
//
//  Created by Simon Lang on 12.06.2024.
//

import SwiftUI

struct YearlyMonthlyStatisticView: View {
    @ObservedObject var downwindManager: DownwindManager
    let yearIndex: Int
    var monthIndex: Int? = nil
    
    var body: some View {
        let sessionsCount = downwindManager.calculateSessions(for: yearIndex, month: monthIndex)
        Label(sessionsCount == 1 ? "\(sessionsCount) session" : "\(sessionsCount) sessions", systemImage: "trophy.fill")
        let distanceString = downwindManager.calculateDownwindDistance(for: yearIndex, month: monthIndex)
        if distanceString != "" {
            Label("\(distanceString) of downwind foiling", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
        }
        let timeString = downwindManager.calculateTimeOnWater(for: yearIndex, month: monthIndex)
        if timeString != "" {
            Label("\(timeString) spent on the water", systemImage: "stopwatch")
        }
    }
}

#Preview {
    List {
        YearlyMonthlyStatisticView(downwindManager: DownwindManager(), yearIndex: 0, monthIndex: 0)
    }
}
