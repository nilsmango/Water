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

    @State private var isRefundRequestPresented = false
    @State private var transactionID: UInt64? = nil
    @State private var showUpgradeView = false
    
    var body: some View {
        List {
            Section {
                // TODO: Refund testing
                if let transactionID = transactionID {
                    Button("Request a Refund") {
                        isRefundRequestPresented = true
                    }
                    .refundRequestSheet(for: transactionID, isPresented: $isRefundRequestPresented) { result in
                        switch result {
                        case .success(let status):
                            print("Refund request status: \(status)")
                        case .failure(let error):
                            print("Refund request error: \(error)")
                        }
                    }
                }
                Link("Privacy Policy", destination: URL(string: "https://project7iii.com/tracker/privacy-policy/")!)
                Link("Terms and Conditions", destination: URL(string: "https://project7iii.com/tracker/terms-and-conditions/")!)
                Link("Contact Us", destination: URL(string: "mailto:tracker@project7iii.com")!)
                if downwindManager.hasPurchasedPremium {
                    Text("Your Premium Status: \(downwindManager.purchasedProducts.first?.displayName ?? "unknown")")
                } else {
                    Button("Get Premium") {
                        showUpgradeView = true
                    }
                    
                    Button("Restore Purchase") {
                        Task {
                            await downwindManager.updateCustomerProductStatus()
                        }
                    }
                }
                
                
                
            } header: {
                Text("How can we help?")
            }
        }
        .navigationTitle("Help")
        .onAppear {
            fetchTransactionID()
        }
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
    }
    
    func fetchTransactionID() {
        // Fetch the transaction ID from your stored transactions
        // Here we assume you have a way to get the last transaction ID
        // This is a simplified example. You may need to adjust it based on how you manage transactions in your app.
        if let lastTransaction = fetchLastTransaction() {
            transactionID = lastTransaction.id
        }
    }
    
    func fetchLastTransaction() -> SpecialTransaction? {
        // Implement this function to return the last transaction.
        // You should fetch the actual transaction from your app's transaction storage mechanism.
        // For demonstration, we're returning nil.
        return nil
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
