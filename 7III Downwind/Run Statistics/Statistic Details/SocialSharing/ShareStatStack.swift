//
//  ShareStatStack.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI

struct ShareStatStack: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    ShareStatStack(title: "DW SUP Foil", value: "23.53 km")
}
