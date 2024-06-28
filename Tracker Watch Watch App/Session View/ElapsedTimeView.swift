//
//  ElapsedTimeView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct ElapsedTimeView: View {
    var elapsedTime: TimeInterval = 0
    var showSubseconds: Bool = true
    @State private var timeFormatter = ElapsedTimeFormatter()
    
    var body: some View {
        Text(NSNumber(value: elapsedTime), formatter: timeFormatter)
            .fontWeight(.semibold)
            .onChange(of: showSubseconds, { oldValue, newValue in
                timeFormatter.showSubseconds = newValue
            })
    }
}

#Preview {
    ElapsedTimeView()
}
