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
            ForEach(downwindManager.activeRun.members) { member in
                Text(member.name)
                Text("Location:")
            }
        }
    }
}

#Preview {
    RunView(downwindManager: DownwindManager())
}
