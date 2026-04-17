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
            .background {
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        Color.whiteAndBlack.opacity(0.8)
                    )
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 26))
            .padding(.trailing, 16)
        } else {
            // Fallback on earlier versions
        }
    }
}

struct FakePicker: View {
    let items: [String]
    let selected: String

    var body: some View {
        if #available(iOS 26.0, *) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.orange)
                            .opacity(item == selected ? 1 : 0)
                        Text(item)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
            .frame(width: 250)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        Color.whiteAndBlack.opacity(0.8)
                    )
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 26))
            .padding(.trailing, 16)
        } else {
        }
    }
}

#Preview {
    VStack {
        FakeMenu(items: [FakeMenuItem(title: "Video", icon: "film"), FakeMenuItem(title: "Map Photo", icon: "photo"), FakeMenuItem(title: "Sticker Overlay", icon: "square.dashed"), FakeMenuItem(title: "GPX", icon: "point.bottomleft.forward.to.point.topright.scurvepath")])
        
        FakePicker(items: [
            "Foil Surf",
            "SUP Foil",
            "DW SUP Foil",
            "DW SUP",
            "DW Prone Foil",
            "Wing Foil",
            "Parawing",
            "DW Parawing",
            "Wind Foil",
            "Kite Foil",
            "Kite",
            "Windsurf",
            "Pump Foil",
            "Wake Thief",
            "Wake Foil",
            "Wake Surf"
        ], selected: "DW SUP Foil")
    }
    
}
