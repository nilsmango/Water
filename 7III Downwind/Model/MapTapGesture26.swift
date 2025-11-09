//
//  MapTapGesture26.swift
//  7III Tracker
//
//  Created by Simon Lang on 09.11.2025.
//

import SwiftUI

extension View {
    /// ios26 is not responding to Map tap gestures - this is a workaround
    func onTapGestureBugFix(_ action: @escaping (CGPoint) -> Void) -> some View {
        modifier(TapGestureModifier(action: action))
    }
}

struct TapGestureModifier: ViewModifier {
    var action: ((CGPoint) -> Void)
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.simultaneousGesture(SpatialTapGesture().onEnded { event in
                action(event.location)
            })
        }
        else {
            content.onTapGesture { location in
                action(location)
            }
        }
    }
}
