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
        if sessions.total == 0 {
            Label(sessions.total == 1 ? "\(sessions.total) Session" : "\(sessions.total) Sessions", systemImage: "trophy.fill")
        } else {
            DisclosureGroup {
                ForEach(sessions.types.sorted(by: { $0.value > $1.value }), id: \.key) { session in
                    if session.value > 0 {
                        Text("\(session.value) x \(session.key.prettyString)")
                    }
                }
            } label: {
                Label(sessions.total == 1 ? "\(sessions.total) Session" : "\(sessions.total) Sessions", systemImage: "trophy.fill")
            }
        }

        // Time on water
        let timeData = downwindManager.calculateTimeOnWater(for: yearIndex, month: monthIndex)
        if !timeData.total.isEmpty {
            DisclosureGroup {
                ForEach(timeData.types.sorted(by: { $0.value > $1.value }), id: \.key) { time in
                    var prettyString = time.key.prettyString
                    if prettyString.last == "e" {
                        Text("\(time.value) of \(prettyString.removeLast())ing")
                    } else {
                        Text("\(time.value) of \(prettyString)ing")
                    }
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
                    let prettyString = distance.key.prettyString
                    if prettyString == "Paddling" || prettyString == "Wake Thief" || prettyString == "Sailing" || prettyString == "Canoe" {
                        Text("\(distance.value) of \(prettyString)")
                    } else if prettyString.last == "e" {
                        Text("\(distance.value) of \(prettyString.dropLast())ing")
                    } else {
                        Text("\(distance.value) of \(prettyString)ing")
                    }
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
                    let prettyString = distance.key.prettyString
                    if prettyString.last == "e" {
                        Text("\(distance.value) of \(prettyString.dropLast())ing")
                    } else {
                        Text("\(distance.value) of \(prettyString)ing")
                    }
                }
            } label: {
                Label("\(dwDistanceData.total) of Downwind", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
            }
        }
    }
}

class MockDownwindManager: DownwindManager {
    override func calculateSessions(for yearIndex: Int, month: Int?) -> (total: Int, types: [WorkoutType: Int]) {
        return (15, [.dWParawing: 1, .parawing: 4, .pumpFoil: 5, .foilSurf: 2, .wingFoil: 3])
    }

    override func calculateTimeOnWater(for yearIndex: Int, month: Int?) -> (total: String, types: [WorkoutType: String]) {
        return ("15h 30m", [.dWParawing: "2h", .parawing: "4h", .pumpFoil: "5h 30m", .foilSurf: "2h", .wingFoil: "2h"])
    }
    
    override func calculateDistance(for yearIndex: Int, month: Int?) -> (total: String, types: [WorkoutType: String]) {
        return ("150 km", [.dWParawing: "20 km", .downwindSUPFoil: "40 km", .downwindProneFoil: "30 km", .windFoil: "30 km", .foilSurf: "20 km", .kite: "10 km"])
    }
    
    override func calculateDownwindDistance(for yearIndex: Int, month: Int?) -> (total: String, types: [WorkoutType: String]) {
        return ("90 km", [.dWParawing: "20 km", .kite: "40 km", .downwindProneFoil: "30 km"])
    }
}

#Preview {
    List {
        YearlyMonthlyStatisticView(downwindManager: MockDownwindManager(), yearIndex: 0, monthIndex: 0)
    }
}
