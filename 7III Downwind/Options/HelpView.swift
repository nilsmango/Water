//
//  HelpView.swift
//  7III Tracker
//
//  Created by Simon Lang on 08.07.2024.
//

import SwiftUI

struct HelpView: View {
    @ObservedObject var downwindManager: DownwindManager

    @State private var showUpgradeView = false
    @State private var showManage = false
    @State private var showRefundSheet = true
    
    var body: some View {
        List {
            Section {
                NavigationLink("Request a Refund") {
                    RefundView(downwindManager: downwindManager)
                }
                Group {
                    Link("Privacy Policy", destination: URL(string: "https://project7iii.com/water/privacy-policy/")!)
                    
                    Link("Terms and Conditions", destination: URL(string: "https://project7iii.com/water/terms-and-conditions/")!)
                    Link("Contact us", destination: URL(string: "mailto:hi@project7iii.com")!)
                }
                
            } header: {
                Text("How can we help?")
            } footer: {
                Text("Use **Contact us** to ask for support, report bugs, or send suggestions.\n\nApp Version: \(downwindManager.currentAppVersion)")
            }
            
            
            PremiumSection(downwindManager: downwindManager, showUpgradeView: $showUpgradeView, showManage: $showManage)

        }
        .navigationTitle("Help")
        .sheet(isPresented: $showUpgradeView, content: {
            NavigationStack {
                UpgradeView(downwindManager: downwindManager, showUpgradeView: $showUpgradeView)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showUpgradeView = false
                            } label: {
                                Label("Close", systemImage: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .gray)
                            }
                        }
                    }
            }
        })
        .manageSubscriptionsSheet(isPresented: $showManage)
        .onAppear {
            Task {
                await downwindManager.updateCustomerProductStatus()
            }
        }
        .onChange(of: showManage) {
            if showManage == false {
                Task {
                    await downwindManager.updateCustomerProductStatus()
                }
            }
        }
    }
}

struct SpecialTransaction {
    var id: UInt64
    // Add other properties as needed
}


#Preview {
    NavigationStack {
        HelpView(downwindManager: DownwindManager())
    }
}
