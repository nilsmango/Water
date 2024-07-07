//
//  LevelView.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.07.2024.
//

import SwiftUI

struct LevelView: View {
    var body: some View {
        Text("Level")
        HStack {
            HStack(spacing: -2) {
//                Image(systemName: "star.fill")
//                Image(systemName: "star.fill")
//                Image(systemName: "star.fill")
                Image(systemName: "medal.fill")
            }
            .foregroundStyle(.yellow)
            
            
            
            Text("Poseidon Goat")
                .foregroundStyle(.background)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Capsule().fill(.foreground))
    }
}

#Preview {
    LevelView()
}
