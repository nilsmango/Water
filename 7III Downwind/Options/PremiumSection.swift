//
//  PremiumSection.swift
//  7III Tracker
//
//  Created by Simon Lang on 15.07.2024.
//

import SwiftUI
import StoreKit

struct PremiumSection: View {
    @ObservedObject var downwindManager: DownwindManager
    @Binding var showUpgradeView: Bool
    @Binding var showManage: Bool
    
    var body: some View {
        Section {
            if downwindManager.hasPurchasedPremium {
                UpgradeStatus(
                    displayName: downwindManager.purchasedProducts.first?.displayName,
                    image: downwindManager.createImageForPurchasedProduct(),
                    nextBilling: downwindManager.nextBillingText
                )
                
                if downwindManager.subscriptionRenewalDate != nil {
                    Button {
                        showManage = true
                    } label: {
                        Text("Manage Subscription")
                    }
                }
            } else {
                Button {
                    showUpgradeView = true
                } label: {
                    Label("Get Premium", systemImage: "sparkles")
                }
                
                Button {
                    Task {
                        try? await AppStore.sync()
                    }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("Premium")
        }
    }
}

#Preview {
    List {
        PremiumSection(downwindManager: DownwindManager(), showUpgradeView: .constant(false), showManage: .constant(false))
    }
}
