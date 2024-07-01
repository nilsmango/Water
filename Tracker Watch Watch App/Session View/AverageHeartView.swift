//
//  AverageHeartView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 01.07.2024.
//

import SwiftUI

struct AverageHeartView: View {
    var body: some View {
        HStack(spacing: -1.0) {
            Text("∅-")
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundColor(.red)
                .scaleEffect(0.9)
        }
    }
}

#Preview {
    AverageHeartView()
}
