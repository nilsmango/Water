//
//  NoActiveRunnersView.swift
//  7III Downwind
//
//  Created by Simon Lang on 23.01.2024.
//

import SwiftUI

struct NoActiveRunnersView: View {
    var body: some View {
        Label("No Active Runners Found", systemImage: "water.waves.slash")
            .labelStyle(.titleAndIcon)
    }
}

#Preview {
    NoActiveRunnersView()
}
