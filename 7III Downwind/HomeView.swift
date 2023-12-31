//
//  HomeView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var body: some View {
        if downwindManager.user.id == nil {
            FirstTimeUserNameSet(downwindManager: downwindManager)
        } else {
            if downwindManager.activeRun.active {
                RunView(downwindManager: downwindManager)
            } else {
                VStack {
                    Text("Aloha \(downwindManager.user.name)!")
                        .font(.largeTitle)
                        .padding(.bottom, 60)
                    
                    Text("You have not been added to an active run yet.")
                        .padding(.bottom, 30)
                    
                    Button(action: {
                        // Check for Run with yourself
                    }, label: {
                        Text("Recheck")
                    })
                    
                    Text("or")
                    
                    Button(action: {
                        // New Run
                    }, label: {
                        Text("Start New Run")
                    })
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    HomeView(downwindManager: DownwindManager())
}
