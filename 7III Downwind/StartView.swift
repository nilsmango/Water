//
//  StartView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct StartView: View {
    @StateObject private var downwindManager = DownwindManager()
    
    @State private var showSplash = true
    
    var body: some View {
        if showSplash {
            SplashView()
                .onAppear {
                        Task {
                            do {
                                try await downwindManager.loadActiveRun()
                                
                            } catch {
                                print("Error: \(error)")
                            }
                        }
                    
                    downwindManager.loadUser()
                    showSplash = false
                }
        } else {
            HomeView(downwindManager: downwindManager)
        }
    }
}

#Preview {
    StartView()
}
