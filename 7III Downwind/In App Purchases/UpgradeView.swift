//
//  UpgradeView.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.07.2024.
//

import SwiftUI

struct UpgradeView: View {
    @ObservedObject var downwindManager: DownwindManager

    @State private var selection: Tab = .poseidon
    
    enum Tab {
        case poseidon, weekend, kook
    }
    var body: some View {
            VStack {
                Text("Sessions left: \(downwindManager.freeTrackerSessionsNumber - downwindManager.trackerSessionsCount) of \(downwindManager.freeTrackerSessionsNumber)")
                Text("You have almost reached the end of your free sessions, you might consider upgrading to the Water Master version")
                
                
                TabView(selection: $selection) {

                    UpgradeShowcase(image: Image("poseidonGoat"), title: "Poseidon Goat", subTitle: "Be ready for the seven seas. . Includes Future Features as: Crew Live Location Sharing.", price: "$ 5.99", color: .trackerGold)
                        .padding()
                        .tag(Tab.poseidon)
                    
                    UpgradeShowcase(image: Image("poseidonGoat"), title: "Weekend Warrior", subTitle: "Be ready for the seven seas. . Includes Future Features as: Crew Live Location Sharing.", price: "$ 5.99", color: .trackerGold)
                        .padding()
                        .tag(Tab.weekend)
                    
                    UpgradeShowcase(image: Image("poseidonGoat"), title: "Kook", subTitle: "Be ready for the seven seas. . Includes Future Features as: Crew Live Location Sharing.", price: "$ 5.99", color: .trackerGold)
                        .padding()
                        .tag(Tab.kook)
                }
                .tabViewStyle(PageTabViewStyle())
                        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
            }
        
    }
}

#Preview {
    UpgradeView(downwindManager: DownwindManager())
}
