//
//  StatisticsRounds.swift
//  7III Location
//
//  Created by Simon Lang on 04.04.2024.
//

import SwiftUI

struct RoundData: Hashable {
    let first: String
    let second: String
}

struct StatisticsRounds: View {
    @ObservedObject var downwindManager: DownwindManager

    let statisticsData: RunStatistic

    var body: some View {
        let rounds = downwindManager.createRounds(for: statisticsData.locationData)
        List {
            HStack {
                Text("km")
                Spacer()
                Text("min")
            }
            ForEach(rounds.map { RoundData(first: $0.0, second: $0.1) }, id: \.self) { round in
                HStack {
                    Text(round.first)
                    Spacer()
                    Text(round.second)
                }
                .monospacedDigit()
            }
        }
    }
}

#Preview {
    StatisticsRounds(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 300, runDistance: 20, topSpeed: 23, locationData: decodeLocationSampleData() ?? Constants.locationSampleData))
}
