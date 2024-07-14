//
//  OptionsMenu.swift
//  7III Downwind
//
//  Created by Simon Lang on 26.01.2024.
//

import SwiftUI

struct StartOptionsMenu: View {
    @ObservedObject var downwindManager: DownwindManager

    @Binding var showOptionsSheet: Bool
    @Binding var showAboutSheet: Bool
    var body: some View {
        Menu {
            NavigationLink(destination: AboutView(downwindManager: downwindManager)) {
                Label("About", systemImage: "info.circle")
            }
            
            Button(action: {
                showOptionsSheet = true
            }, label: {
                Label("Options", systemImage: "gear")

            })
                        
            NavigationLink(destination: HelpView(downwindManager: downwindManager)) {
                Label("Help", systemImage: "questionmark.circle")
            }
            
//            Button(action: {
//                showAboutSheet = true
//            }, label: {
//                Label("About", systemImage: "info.circle")
//
//            })
            
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                
        }
        .font(.title3)
        
        
    }
}

#Preview {
    StartOptionsMenu(downwindManager: DownwindManager(), showOptionsSheet: .constant(false), showAboutSheet: .constant(false))
}
