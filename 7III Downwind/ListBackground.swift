//
//  ListBackground.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.02.2025.
//

import SwiftUI

struct ListBackground: View {
    var special = false
    var body: some View {
        RoundedRectangle(cornerRadius: 10.0)
            .fill(special ? .accent.opacity(0.2) : .listForeground)
    }
}
