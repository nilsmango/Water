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
    let third: String
}

struct StatisticsRounds: View {
    @ObservedObject var downwindManager: DownwindManager

    let rounds: [(String, String, String)]
    
    var overViewLayout = false
    
    let width = UIScreen.main.bounds.width / 3

    var body: some View {
            HStack {
                Text("Round (km)")
                 .frame(width: width, alignment: .leading)
                Text("Pace (min)")
                Spacer()
                Text("")
            }
        
        ForEach(rounds.map { RoundData(first: $0.0, second: $0.1, third: $0.2) }, id: \.self) { round in
            if !overViewLayout || round.third != "" {
                HStack {
                    Text(round.first)
                        .frame(width: width, alignment: .leading)
                    Text(round.second)
                    Spacer()
                    Text(round.third)
                }
                .monospacedDigit()
            }
        }
    }
}

#Preview {
    List {
        StatisticsRounds(downwindManager: DownwindManager(), rounds: [("1", "6:06", "🐌"), ("2", "4:15", ""), ("3", "2:47", ""), ("4", "2:50", ""), ("5", "2:37", "🚀"), ("6", "2:40", ""), ("7", "2:43", ""), ("8", "2:42", ""), ("9", "2:38", ""), ("10", "3:44", ""), ("11", "3:35", ""), ("12", "2:55", ""), ("13", "2:47", ""), ("14", "2:44", ""), ("15", "2:41", ""), ("16", "2:49", ""), ("17", "2:41", ""), ("18", "3:55", ""), ("19", "3:30", ""), ("20", "2:41", ""), ("21", "2:47", ""), ("22", "2:48", ""), ("22.9", "3:10", "")])
    }
    
}
