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
        if #available(iOS 26.0, *) {
            ConcentricRectangle(
                corners: .concentric,
                isUniform: true
            )
            .fill(special ? .accent : .listForeground)
            .containerShape(
                        .rect(cornerRadius: 24)
                    )
        } else {
            RoundedRectangle(cornerRadius: 10.0)
                .fill(special ? .accent : .listForeground)
        }
    }
}
