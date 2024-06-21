//
//  CoordinatesListView.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2024.
//

import SwiftUI

struct CoordinatesListView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var body: some View {
        List {
            Section {
                let filteredMembers = downwindManager.activeRun.members.filter { $0.onlyWatching ?? false == false}
                if filteredMembers.count > 0 {
                    ForEach(filteredMembers) { member in
                        MemberListView(member: member, distance: nil, degrees: 0.0, measurementSystem: downwindManager.measurementSystem, showDetail: true)
                    }
                } else {
                    NoActiveRunnersView()
                }
                
            } footer: {
                ListInfoLabel(members: downwindManager.activeRun.members, userWatching: true)
            }
            
        }
    }
}

#Preview {
    CoordinatesListView(downwindManager: DownwindManager())
}
