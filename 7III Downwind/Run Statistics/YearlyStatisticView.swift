//
//  YearlyStatisticView.swift
//  7III Tracker
//
//  Created by Simon Lang on 12.06.2024.
//

import SwiftUI

struct YearlyStatisticView: View {
    @ObservedObject var downwindManager: DownwindManager
    let yearIndex: Int
    
    var sessionsText: String {
        if yearIndex > 0 {
            return "Sessions: "
        } else {
            return "Sessions so far: "
        }
    }
    
    var body: some View {
            Text("\(sessionsText)\(downwindManager.calculateSessions(for: yearIndex))")

    }
}

#Preview {
    YearlyStatisticView(downwindManager: DownwindManager(), yearIndex: 0)
}
