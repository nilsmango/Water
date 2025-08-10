//
//  DashboardRow.swift
//  7III Tracker
//
//  Created by Simon Lang on 10.08.2025.
//

import SwiftUI

struct DashboardRow: View {
    let name: String
    let isWidgetEnabled: Bool
    var body: some View {
        HStack {
            Text(name)
            
            if isWidgetEnabled {
                Image(systemName: "pin.square.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
}

#Preview {
    List {
        DashboardRow(name: "Bielersee", isWidgetEnabled: true)
    }
    
}
