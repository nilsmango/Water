//
//  AllRunsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 12.01.24.
//

import SwiftUI

struct AllRunsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var body: some View {
        let moreThanOneRun = downwindManager.allRuns.count > 1
        NavigationStack {
            VStack {
                List {
                    ForEach(downwindManager.allRuns) { run in
                        Section {
                            RunOverView(downwindManager: downwindManager, run: run)
                        }
                    }
                }
                
                Button(role: .destructive, action: {
                    Task {
                        do {
                            try await downwindManager.removeUserFromAllRuns()
                        } catch {
                            print("Error removing user from all runs: \(error)")
                        }
                    }
                    
                }, label: {
                    Label(moreThanOneRun ? "Remove From All Runs" : "Remove From Run", systemImage: "xmark.circle")
                })
                .buttonStyle(.bordered)
                .padding()
                
            }
            .navigationTitle(moreThanOneRun ? "You have been added to the following runs:" : "You have been added to the following run:")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AllRunsView(downwindManager: DownwindManager())
}
