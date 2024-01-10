//
//  RunView.swift
//  7III Downwind
//
//  Created by Simon Lang on 31.12.23.
//

import SwiftUI

struct RunView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var body: some View {
        List {
            Text("Run View")
            ForEach(downwindManager.activeRun.members) { member in
                Text(member.name)
                Text("Location:")
                if let unwrappedLatitude = member.latitude {
                    Text("Latitude: \(unwrappedLatitude)")
                } else {
                    Text("No Data")
                }
                if let unwrappedLongitude = member.longitude {
                    Text("Longitude: \(unwrappedLongitude)")
                }
            }
        }
        .onAppear {
            Task {
                do {
                    try await downwindManager.loadRunMembers()
                    
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
}

#Preview {
    RunView(downwindManager: DownwindManager())
}
