//
//  SessionLeft.swift
//  7III Tracker
//
//  Created by Simon Lang on 08.07.2024.
//

import SwiftUI

struct SessionLeft: View {
    var freeSessions: Int
    var doneSession: Int
    
    var body: some View {
        Label("Sessions left: \(freeSessions - doneSession) of \(freeSessions)", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    SessionLeft(freeSessions: 7, doneSession: 2)
}
