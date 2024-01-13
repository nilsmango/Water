//
//  RunOverView.swift
//  7III Downwind
//
//  Created by Simon Lang on 12.01.24.
//

import SwiftUI

struct RunOverView: View {
    @ObservedObject var downwindManager: DownwindManager
    var run: Run
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("**\(run.name)** | Started: \(Text(run.startedOn ?? Date.now, style: .timer))")
                .monospacedDigit()
//                .padding(.bottom, 3.0)
            Text(run.members.filter { $0.id != downwindManager.user.id }.map { $0.name }.joined(separator: ", "))
            
            Button(action: {
                Task {
                    do {
                        try await downwindManager.startActiveRun(run: run)
                    } catch {
                        print("Error starting active run: \(error)")
                    }
                }
            }, label: {
                Label("Join Run", systemImage: "wind")
            })
            .buttonStyle(.bordered)
            
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15.0)
                .foregroundStyle(Color("ListForeground"))
        }
    }
}

#Preview {
    ZStack {
        Rectangle()
            .foregroundStyle(Color("ListBackground"))
            .ignoresSafeArea()
        RunOverView(downwindManager: DownwindManager(), run: Run(name: "Test Run 01", members: [Member(id: UUID(), name: "Kay Lenny"), Member(id: UUID(), name: "James Casey"), Member(id: UUID(), name: "Nils Mango"), Member(id: UUID(), name: "Mark Zuckerberg")], active: true, startedOn: Date.now - 23))
    }
        
        
}
