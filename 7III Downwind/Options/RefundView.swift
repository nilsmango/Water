//
//  RefundView.swift
//  7III Tracker
//
//  Created by Simon Lang on 15.07.2024.
//

import SwiftUI
import StoreKit

struct RefundView: View {
    @ObservedObject var downwindManager: DownwindManager

    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTrigger = false
    
    var body: some View {
            Group {
                if isLoading {
                    ProgressView("Loading transactions...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else if transactions.isEmpty {
                    Text("No purchases found")
                } else {
                    List(transactions, id: \.id) { transaction in
                        TransactionRow(downwindManager: downwindManager, transaction: transaction, refreshTrigger: $refreshTrigger)
                    }
                }
            }
            .navigationTitle("Request a Refund")
        .onAppear {
            loadTransactions()
        }
        
        .onChange(of: refreshTrigger) { _, _ in
            loadTransactions()
        }
    }
    
    private func loadTransactions() {
        transactions = []  // Clear existing transactions
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch all transactions
                for await verificationResult in Transaction.all {
                    switch verificationResult {
                    case .unverified(_, let error):
                        print("Unverified transaction: \(error.localizedDescription)")
                        // Optionally handle unverified transactions
                    case .verified(let transaction):
                        DispatchQueue.main.async {
                            if transaction.revocationDate == nil, transactions.count < 11 {
                                self.transactions.append(transaction)
                            }
                        }
                    }
                }
                
                // Sort transactions
                DispatchQueue.main.async {
                    self.transactions.sort { $0.purchaseDate > $1.purchaseDate }
                    self.isLoading = false
                }
            }
        }
    }
}

struct TransactionRow: View {
    @ObservedObject var downwindManager: DownwindManager

    let transaction: Transaction
    @State private var refundStatus: String?
    @State private var showRefundSheet = false
    @Binding var refreshTrigger: Bool
    
    var body: some View {
        let product = downwindManager.premiumProducts.first(where: { $0.id == transaction.productID })
        
        HStack {
            CircleImage(image: downwindManager.createImageForPurchasedProduct(product: product), shadow: false)
                .frame(height: 75)
            
            VStack(alignment: .leading, spacing: 5) {
                
                Text(product?.displayName ?? transaction.productID)
                    .font(.headline)
                Text("Purchased: \(formattedDate(transaction.purchaseDate))")
                    .font(.subheadline)
                
                if let status = refundStatus {
                                    Text(status)
                                        .foregroundColor(status.contains("Error") ? .red : .green)
                                        .font(.caption)
                                } else {
                                    Button("Request Refund") {
                                        showRefundSheet = true
                                    }
                                }
            }
            .padding(.vertical, 5)
        }
        .refundRequestSheet(for: transaction.id, isPresented: $showRefundSheet, onDismiss: { result in
            handleRefundResult(result)
        })
       
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func handleRefundResult(_ result: Result<Transaction.RefundRequestStatus, Transaction.RefundRequestError>) {
            switch result {
            case .success(let status):
                switch status {
                case .success:
                    refundStatus = "Refund successful"
                    refreshTrigger.toggle()
                case .userCancelled:
                    refundStatus = "Refund cancelled"
                    refreshTrigger.toggle()
                @unknown default:
                    refundStatus = "Unknown status"
                    refreshTrigger.toggle()
                }
            default:
                refreshTrigger.toggle()
            }
        }
}


#Preview {
    NavigationStack {
        RefundView(downwindManager: DownwindManager())
    }
}

