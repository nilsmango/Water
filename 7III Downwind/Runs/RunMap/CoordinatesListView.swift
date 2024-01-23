//
//  CoordinatesListView.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2024.
//

import SwiftUI

struct CoordinatesListView: View {
    var members: [Member]
    var measurementSystem: MeasurementSystem
    
    var body: some View {
        List {
            Section {
                let filteredMembers = members.filter { $0.onlyWatching ?? false == false}
                if filteredMembers.count > 0 {
                    ForEach(filteredMembers) { member in
                        MemberListView(member: member, distance: nil, degrees: 0.0, measurementSystem: measurementSystem, showDetail: true)
                    }
                } else {
                    NoActiveRunnersView()
                }
                
            } footer: {
                ListInfoLabel(members: members, userWatching: true)
            }
            
        }
    }
}

#Preview {
    CoordinatesListView(members: [
        Member(id: UUID(), name: "Lay Kenny", status: "🥶🥶🥶", latitude: 47.127145, longitude: 7.220772, speed: 15.3, lastUpdated: "2024-01-21T13:36:12Z"),
        
        Member(id: UUID(), name: "Mister Bennetts", status: "Foil Flow", latitude: 47.131195, longitude: 7.231034, speed: 22.3),
        
        Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.123295, longitude: 7.220013, speed: 1.3)
    
    ], measurementSystem: .metric)
}
