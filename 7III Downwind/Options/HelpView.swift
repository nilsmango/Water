//
//  HelpView.swift
//  7III Tracker
//
//  Created by Simon Lang on 08.07.2024.
//

import SwiftUI
import StoreKit

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
                    
                    Link("Support Page with FAQ", destination: URL(string: "https://project7iii.com/water/support/")!)
                    
                    Link("Privacy Policy", destination: URL(string: "https://project7iii.com/water/privacy-policy/")!)
                    
                    Link("Terms and Conditions", destination: URL(string: "https://project7iii.com/water/terms-and-conditions/")!)
                    Link("Contact us", destination: URL(string: "mailto:7+water@project7iii.com")!)
                }
                
            } header: {
                Text("How can we help?")
            } footer: {
                Text("Use **Contact us** to report bugs, or send suggestions.\n\nApp Version: \(downwindManager.currentAppVersion) \(downwindManager.currentAppBuild)")
            }

            Section {
                Link("Request a Feature or Report a Bug", destination: URL(string: "https://github.com/nilsmango/7III_Location_App/issues/new/choose")!)

                Link("View the Source Code", destination: URL(string: "https://github.com/nilsmango/7III_Location_App")!)

                Link("How to Contribute", destination: URL(string: "https://github.com/nilsmango/7III_Location_App/blob/main/CONTRIBUTING.md")!)

                Link("Open Source on the Water Website", destination: URL(string: "https://project7iii.com/water/#open-source-built-with-you")!)
            } header: {
                Text("Open Source")
            } footer: {
                Text("Want a feature? Point your AI coding assistant at Water, review and test its work, then open a pull request. Rider feedback, testing, translations, design, and code are all welcome.")
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
                                XMarkLabel()
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
