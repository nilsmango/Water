//
//  RunListView.swift
//  7III Downwind
//
//  Created by Simon Lang on 02.01.24.
//

import SwiftUI

struct RunListView: View {
    private var runMembers = [Member(id: UUID(), name: "Fritz", latitude: 47.43, longitude: 55.4), Member(id: UUID(), name: "Franz", latitude: 48.1, longitude: 55.2), Member(id: UUID(), name: "Florian", latitude: 48.1206, longitude: 55.2018)]
    
    private var myself = Member(id: UUID(), name: "Nils Mango", latitude: 48.1206, longitude: 55.202)
    
    
    var body: some View {
        List {
            ForEach(runMembers) { member in
                HStack {
                    Text(member.name)
                    if let distance = calculateDirectDistance(from: myself, to: member) {
                        Text(makePrettyDistance(meters: distance))
                    } else {
                        Text("No Data")
                    }
                    
                }
            }
        }
    }
}

#Preview {
    RunListView()
}
