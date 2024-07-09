//
//  UpgradeView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 09.07.2024.
//

import SwiftUI

struct UpgradeView: View {
    @ObservedObject var workoutManager: WorkoutManager

    struct FeatureItem: Identifiable {
        let id = UUID()
        let text: String
        let symbol: String
    }

        let features = [
            FeatureItem(text: "Unlimited statistics", symbol: "chart.xyaxis.line"),
            FeatureItem(text: "Unlimited tags", symbol: "tag"),
            FeatureItem(text: "Editing of sessions", symbol: "pencil"),
            FeatureItem(text: "Access to future features like Location Sharing", symbol: "location.fill")
        ]
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Enhance your water sports tracking experience with our premium features.\nYour support helps us continually improve 7III Tracker and develop exciting new capabilities.\n\nAll early adopter offers come with:")
                Text("")
                
                ForEach(features) { feature in
                    HStack {
                        Image(systemName: feature.symbol)
                            .foregroundColor(.primary)
                        Text(feature.text)
                    }
                    .padding(.vertical, 5)
                    
                }
                
                Text("")
                
                WatchUpgradShowcase(image: Image("poseidonGoatW"), title: "GOAT", subTitle: "Pay once, conquer the seven seas.", priceButton: "$9.99 / Lifetime", buttonColor: .darkBlue)
                    .padding(.bottom, 16)
                
                WatchUpgradShowcase(image: Image("weekendWarriorW"), title: "Weekend Warrior", subTitle: "A year of fun for a modest price.", priceButton: "$6.99 / Year", buttonColor: .warriorWatch)
                    .padding(.bottom, 16)

                WatchUpgradShowcase(image: Image("watchKook"), title: "Kook", subTitle: "Hang loose. Pay once a month", priceButton: "$0.99 / Month", buttonColor: .kookSea)
                    .padding(.bottom, 16)
                
                Button {
                    // TODO: redeem code
                } label: {
                    Text("Redeem Code")
                    
                }
                .tint(.primary)
                
                
                Text("[Terms & Conditions](https://project7iii.com/tracker/terms-and-conditions/) and [Privacy Policy](https://project7iii.com/tracker/privacy-policy/)")
                    .font(.caption)
                    .padding(.top, 16)
                
                Text("Note: If you are unable to afford an upgrade, please email us at tracker@project7iii.com for a coupon code.")
                    .font(.caption)
                    .padding(.bottom)
                    .padding(.top, 8)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Upgrade")
    }
}

#Preview {
    UpgradeView(workoutManager: WorkoutManager())
}
