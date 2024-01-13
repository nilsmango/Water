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
        ZStack {
            Rectangle()
                .foregroundStyle(Color("ListBackground"))
                .ignoresSafeArea()
            
            ScrollView {
                Text("You have been added to the following runs:")
                ForEach(downwindManager.allRuns) { run in
                    RunOverView(downwindManager: downwindManager, run: run)
                        .padding(.vertical)
                }
                
                Button(role: .destructive, action: {
                    // TODO: Remove from all runs
                }, label: {
                    Label("Remove From All Runs", systemImage: "xmark.circle")
                })
                .buttonStyle(.bordered)
            }
            
        }
        
    }
}

#Preview {
    AllRunsView(downwindManager: DownwindManager())
}
