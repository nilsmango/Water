//
//  SpotKindPicker.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import SwiftUI

struct SpotKindPicker: View {
    @Binding var kind: Spot.Kind
    var availableKinds: [Spot.Kind]? = nil
    
    var body: some View {
        Picker("Spot Type", selection: $kind) {
            ForEach(availableKinds ?? Spot.Kind.allCases, id: \.self) { kind in
                Label(kind.label, systemImage: kind.iconName)
                    .tag(kind)
            }
        }
    }
}
