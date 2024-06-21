//
//  ListInfoLabel.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2024.
//

import SwiftUI

struct ListInfoLabel: View {
    var members: [Member]
    var userWatching: Bool
    
    private var watchingMembersCount: Int {
        let watchingMembers = members.filter { $0.onlyWatching == true }
        return watchingMembers.count + (userWatching ? 1 : 0)
    }

    var body: some View {
        VStack(alignment: .leading) {
            
            Label("Tap on any row to copy the coordinates", systemImage: "info.circle")
            
            if watchingMembersCount > 0 {
                Label("Watching: \(watchingMembersCount)", systemImage: "eyes")
            }
        }
    }
}

#Preview {
    ListInfoLabel(members: [
        Member(id: UUID(), name: "Lay Kenny", status: "🥶🥶🥶", latitude: 47.127145, longitude: 7.220772, speed: 15.3, lastUpdated: "2024-01-21T13:36:12Z"),
        
        Member(id: UUID(), name: "Mister Bennetts", status: "Foil Flow", latitude: 47.131195, longitude: 7.231034, speed: 22.3),
        
        Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.123295, longitude: 7.220013, speed: 1.3)
    
    ], userWatching: true)
}
