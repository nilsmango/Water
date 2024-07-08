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
        ScrollView {
            VStack {
                Text("To keep tracking your water sports journey, consider upgrading to one of our paid plans.\nAll plans include future features like Location Sharing, and help us continue improving 7III Tracker.")
                
                TabView(selection: $selection) {
                    UpgradeShowcase(image: Image("poseidonGoat"), title: "GOAT", subTitle: "Pay once, conquer the seven seas.", priceButton: "$9.99 / Lifetime", backgroundColor: .darkBlue, buttonColor: .trackerGold, buttonTextColor: .primary)
                        .padding()
                        .tag(Tab.poseidon)
                    
                    UpgradeShowcase(image: Image("weekendWarrior"), title: "Weekend Warrior", subTitle: "A year of fun for a modest price.", priceButton: "$6.99 / Year", backgroundColor: .warriorSky, buttonColor: .kookSea, buttonTextColor: .primary)
                        .padding()
                        .tag(Tab.weekend)
                    
                    UpgradeShowcase(image: Image("kook"), title: "Kook", subTitle: "Hang loose. Pay once a month", priceButton: "$0.99 / Month", backgroundColor: .kookSea, buttonColor: .warriorSky, buttonTextColor: .primary)
                        .padding()
                        .tag(Tab.kook)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                        .frame(height: 620)
                        .padding(.top, -50.0)
                
                Button {
                    // TODO: redeem code
                } label: {
                    Text("Redeem Code")
//                        .fontWeight(.bold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
//                        .background(
//                            Capsule()
//                                .fill(.gray.opacity(0.2))
//                        )
                }
                .tint(.primary)
//                .padding(.top)
                
                Text("Note: If you can't or don't want to spare the change, send us an [email](mailto:tracker@project7iii.com) and we will send you a coupon code.")
                    .font(.caption)
                    .padding([.bottom, .horizontal])
                    .padding(.top, 8)
                    .tint(.red)
            }
            .padding(.horizontal)
        }
        .background(
            .gray.opacity(0.4)
        )
    }
}

#Preview {
    NavigationStack {
        UpgradeView(downwindManager: DownwindManager())
            .navigationTitle("Upgrade")
    }
}
