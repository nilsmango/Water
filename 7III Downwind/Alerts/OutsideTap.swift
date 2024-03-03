//
//  OutsideTap.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.03.2024.
//

import SwiftUI

struct OutsideTap: ViewModifier {
    var onTap: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.0)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
            
            content
        }
    }
}

extension View {
    func outsideTap(onTap: @escaping () -> Void) -> some View {
        self.modifier(OutsideTap(onTap: onTap))
    }
}
