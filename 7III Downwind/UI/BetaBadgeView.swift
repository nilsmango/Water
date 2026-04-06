//
//  BetaBadgeView.swift
//  7III Location
//
//  Created by Codex on 06.04.2026.
//

import SwiftUI

struct BetaBadgeView: View {
    var text: String = "BETA"
    
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.leading, 6)
            .padding(.trailing, 5)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.accentColor)
            )
    }
}

#Preview {
    BetaBadgeView()
}
