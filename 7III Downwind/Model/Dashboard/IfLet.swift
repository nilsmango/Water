//
//  IfLet.swift
//  7III Tracker
//
//  Created by Simon Lang on 10.08.2025.
//

import SwiftUICore

extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(
        _ value: T?,
        transform: (Self, T) -> Content
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
