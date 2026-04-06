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
        // Sessions count
        let sessions = downwindManager.calculateSessions(for: yearIndex, month: monthIndex)
        let sessionSummary = "\(sessions.total) \(sessions.total == 1 ? "Session" : "Sessions") on \(sessions.totalDays) \(sessions.totalDays == 1 ? "Day" : "Days")"
        if sessions.total == 0 {
            Label(sessionSummary, systemImage: "trophy.fill")
        } else {
            DisclosureGroup {
                ForEach(sessions.types.sorted(by: { $0.value > $1.value }), id: \.key) { session in
                    if session.value > 0 {
                        let daysWithSessions = sessions.typeDays[session.key, default: 0]
                        Text("\(session.value) x \(session.key.prettyString) • \(daysWithSessions) \(daysWithSessions == 1 ? "day" : "days")")
                    }
                }
            } label: {
                Label(sessionSummary, systemImage: "trophy.fill")
            }
        }

        // Time on water
        let timeData = downwindManager.calculateTimeOnWater(for: yearIndex, month: monthIndex)
        if !timeData.total.isEmpty {
            DisclosureGroup {
                ForEach(timeData.types.sorted(by: { $0.value > $1.value }), id: \.key) { time in
                    let prettyString = formatActivityName(time.key.prettyString)
                    
                    Text("\(makePrettyTime(timeInMinutes: time.value)) of \(prettyString)")
                }
            } label: {
                Label("\(timeData.total) of Water Time", systemImage: "stopwatch")
            }
        }
        
        // Total distance
        let totalDistanceData = downwindManager.calculateDistance(for: yearIndex, month: monthIndex)
        if !totalDistanceData.total.isEmpty {
            DisclosureGroup {
                ForEach(totalDistanceData.types.sorted(by: { $0.value > $1.value }), id: \.key) { distance in
                    let prettyString = formatActivityName(distance.key.prettyString)
                    
                    Text("\(makePrettyDistance(meters: distance.value, system: downwindManager.measurementSystem)) of \(prettyString)")
                }
            } label: {
                Label("\(totalDistanceData.total) Total Distance", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
            }
        }

        // Downwind distance
        let dwDistanceData = downwindManager.calculateDownwindDistance(for: yearIndex, month: monthIndex)
        if !dwDistanceData.total.isEmpty {
            DisclosureGroup {
                ForEach(dwDistanceData.types.sorted(by: { $0.value > $1.value }), id: \.key) { distance in
                    let prettyString = formatActivityName(distance.key.prettyString)
                    
                    Text("\(makePrettyDistance(meters: distance.value, system: downwindManager.measurementSystem)) of \(prettyString)")
                }
            } label: {
                Label("\(dwDistanceData.total) of Downwind", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
            }
        }
        
        // UpDW distance
        let upDWDistanceData = downwindManager.calculateUpDownwindDistance(for: yearIndex, month: monthIndex)
        if !upDWDistanceData.total.isEmpty {
            DisclosureGroup {
                ForEach(upDWDistanceData.types.sorted(by: { $0.value > $1.value }), id: \.key) { distance in
                    let prettyString = formatActivityName(distance.key.prettyString)
                    
                    Text("\(makePrettyDistance(meters: distance.value, system: downwindManager.measurementSystem)) of \(prettyString)")
                }
            } label: {
                Label("\(upDWDistanceData.total) of Up/Downwind", systemImage: "arrow.up.arrow.down")
            }
        }
    }
}

class MockDownwindManager: DownwindManager {
    override func calculateSessions(for yearIndex: Int, month: Int?) -> (total: Int, totalDays: Int, types: [WorkoutType: Int], typeDays: [WorkoutType: Int]) {
        return (
            15,
            9,
            [.dWParawing: 1, .parawing: 4, .pumpFoil: 5, .foilSurf: 2, .wingFoil: 3],
            [.dWParawing: 1, .parawing: 3, .pumpFoil: 4, .foilSurf: 2, .wingFoil: 2]
        )
    }

    override func calculateTimeOnWater(for yearIndex: Int, month: Int?) -> (total: String, types: [WorkoutType: Double]) {
        return ("12 h", [.dWParawing: 1203, .parawing: 3434, .pumpFoil: 3535, .wingFoil: 2923])
    }
    
    override func calculateDistance(for yearIndex: Int, month: Int?) -> (total: String, types: [WorkoutType: Double]) {
        return ("150 km", [.dWParawing: 20000, .downwindSUPFoil: 40000, .downwindProneFoil: 30000, .windFoil: 30000, .foilSurf: 20000, .kite: 10000])
    }
    
    override func calculateDownwindDistance(for yearIndex: Int, month: Int?) -> (total: String, types: [WorkoutType: Double]) {
        return ("90 km", [.dWParawing: 20000, .kite: 40000, .downwindProneFoil: 30000])
    }
}

#Preview {
    List {
        YearlyMonthlyStatisticView(downwindManager: MockDownwindManager(), yearIndex: 0, monthIndex: 0)
    }
}
