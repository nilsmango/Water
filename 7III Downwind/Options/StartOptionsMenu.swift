//
//  OptionsMenu.swift
//  7III Downwind
//
//  Created by Simon Lang on 26.01.2024.
//

import SwiftUI

struct StartOptionsMenu: View {
    @ObservedObject var downwindManager: DownwindManager

    var body: some View {
        Menu {
            NavigationLink(destination: OptionsView(downwindManager: downwindManager)) {
                Label("Settings", systemImage: "gear")
            }
                        
            NavigationLink(destination: HelpView(downwindManager: downwindManager)) {
                Label("Help", systemImage: "questionmark.circle")
            }
            
            NavigationLink(destination: AboutView(downwindManager: downwindManager)) {
                Label("About", systemImage: "info.circle")
            }
            
            NavigationLink(destination: VersionHistoryView()) {
                Label("Version Log", systemImage: "list.bullet.clipboard")
            }
            
        } label: {
            Label("Options", systemImage: "ellipsis.circle.fill")
                
        }
    }
}

#Preview {
    StartOptionsMenu(downwindManager: DownwindManager())
}
