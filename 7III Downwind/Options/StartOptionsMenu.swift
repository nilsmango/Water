//
//  OptionsMenu.swift
//  7III Downwind
//
//  Created by Simon Lang on 26.01.2024.
//

import SwiftUI

struct StartOptionsMenu: View {
    @Binding var showOptionsSheet: Bool
    @Binding var showAboutSheet: Bool
    var body: some View {
        Menu {
            
            Button(action: {
                showAboutSheet = true
            }, label: {
                Label("About", systemImage: "info.circle")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            })
            
            Button(action: {
                showOptionsSheet = true
            }, label: {
                Label("Options", systemImage: "gear")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            })
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        
        
    }
}

#Preview {
    StartOptionsMenu(showOptionsSheet: .constant(false), showAboutSheet: .constant(false))
}
