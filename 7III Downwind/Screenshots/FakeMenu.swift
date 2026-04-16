//
//  FakeMenu.swift
//  7III Tracker
//
//  Created by Simon Lang on 16.04.2026.
//

import SwiftUI

struct FakeMenuItem {
    let title: String
    let icon: String
}

struct FakeMenu: View {
    let items: [FakeMenuItem]
    
    var body: some View {
        if #available(iOS 26.0, *) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items, id: \.self.title) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 24)
                        Text(item.title)
                        
                        Spacer()
                    }
                    .frame(width: 200)
                }
                
            }
            .padding(18)
            .glassEffect(in: RoundedRectangle(cornerRadius: 26))
            .padding(.trailing, 16)
        } else {
            // Fallback on earlier versions
        }
    }
}

#Preview {
    FakeMenu(items: [FakeMenuItem(title: "Video", icon: "film"), FakeMenuItem(title: "Map Photo", icon: "photo"), FakeMenuItem(title: "Sticker Overlay", icon: "square.dashed"), FakeMenuItem(title: "GPX", icon: "point.bottomleft.forward.to.point.topright.scurvepath")])
}
