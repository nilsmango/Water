//
//  XMarkLabel.swift
//  7III Tracker
//
//  Created by Simon Lang on 30.09.2025.
//

import SwiftUI

struct XMarkLabel: View {
    var body: some View {
        if #available(iOS 26, *) {
            Label("Close", systemImage: "xmark")
        } else {
            Label("Close", systemImage: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .gray)
        }
    }
}

#Preview {
    XMarkLabel()
}
