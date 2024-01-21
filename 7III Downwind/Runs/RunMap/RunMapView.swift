//
//  RunMapView.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2024.
//

import SwiftUI

struct RunMapView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var isShowingAlert = false
    
    var body: some View {
        VStack {
            MapView(members: downwindManager.activeRun.members, user: downwindManager.user, measurementSystem: downwindManager.measurementSystem)
            
            HStack {
                Button(role: .destructive, action: {
                    isShowingAlert = true
                    
                }, label: {
                    Label("Exit Run", systemImage: "door.left.hand.open")
                })
                .buttonStyle(.bordered)
                .padding()
                
                OptionsMenu(sorting: $downwindManager.runListSorting, measurement: $downwindManager.measurementSystem, showListDetail: $downwindManager.showListDetail)
                    .buttonStyle(.bordered)
                    .padding()
                
            }
        }
    }
}

#Preview {
    RunMapView(downwindManager: DownwindManager())
}
