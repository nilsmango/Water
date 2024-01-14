//
//  MemberView.swift
//  7III Downwind
//
//  Created by Simon Lang on 14.01.24.
//

import SwiftUI

struct MemberView: View {
    
    var isInRun: Bool
    var memberName: String
    
    var body: some View {
        HStack {
            Image(systemName: isInRun ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isInRun ? .blue : .primary)
            Text(memberName)
        }
    }
}

#Preview {
    MemberView(isInRun: true, memberName: "Kay Lenny")
}
