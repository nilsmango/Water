//
//  UpgradeView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 09.07.2024.
//

import SwiftUI
import StoreKit

struct UpgradeView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var showUpgradeView: Bool

    @State private var wasPurchased = false
    @State private var isShowingError = false
    @State private var errorTitle = ""

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
        if workoutManager.unableToLoadProducts {
            VStack {
                Text("Unable to load products.")
                Text("If you are offline, try again when online.")
                Button("Try Again") {
                    Task {
                        await workoutManager.loadProductIdentifiersAndRequestProducts()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Upgrade")
            
        }  else if !SKPaymentQueue.canMakePayments() {
            VStack {
                Text("Your device can't make purchases, either because another person has parental controls, or the device has a mobile device management (MDM) profile that blocks purchases.")
            }
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Enhance your water sports tracking experience with our premium features.\nYour support helps us continually improve 7III Water and develop exciting new capabilities.\n\nAll early adopter offers come with:")
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
                    
                    if workoutManager.premiumProducts.isEmpty {
                        HStack {
                            Spacer()
                            VStack {
                                ProgressView("Loading Products")
                                Text("If nothing loads please email us at hi@project7iii.com")
                            }
                            Spacer()
                        }
                        .frame(minHeight: 40)
                    } else {
                        if let goatProduct = workoutManager.premiumProducts.first(where: { $0.id == "com.project7iii.tracker.goat"}) {
                            WatchUpgradeShowcase(image: Image("poseidonGoatW"), title: goatProduct.displayName, subTitle: goatProduct.description, priceButton: "\(goatProduct.displayPrice) / Lifetime", buttonColor: .darkBlue, makeLabel: wasPurchased) { Task {
                                await buy(product: goatProduct)
                            }}
                            .padding(.bottom, 16)
                        }
                        
                        if let weekendWarriorProduct = workoutManager.premiumProducts.first(where: { $0.id == "com.project7iii.tracker.weekend_warrior"}) {
                            WatchUpgradeShowcase(image: Image("weekendWarriorW"), title: weekendWarriorProduct.displayName, subTitle: weekendWarriorProduct.description, priceButton: "\(weekendWarriorProduct.displayPrice) / Year", buttonColor: .warriorWatch, makeLabel: wasPurchased) { Task {
                                await buy(product: weekendWarriorProduct)
                            }}
                            .padding(.bottom, 16)
                        }
                        
                        if let kookProduct = workoutManager.premiumProducts.first(where: { $0.id == "com.project7iii.tracker.kook"}) {
                            WatchUpgradeShowcase(image: Image("watchKook"), title: kookProduct.displayName, subTitle: kookProduct.description, priceButton: "\(kookProduct.displayPrice) / Month", buttonColor: .kookSea, makeLabel: wasPurchased) { Task {
                                await buy(product: kookProduct)
                            }}
                            .padding(.bottom, 16)
                        }
                    }
                                        
                    Text("[Terms & Conditions](https://project7iii.com/water/terms-and-conditions/) and [Privacy Policy](https://project7iii.com/water/privacy-policy/)")
                        .font(.caption)
                        .padding(.top, 16)
                    
                    Text("Note: If you are unable to afford an upgrade, please email us at hi@project7iii.com for a coupon code.")
                        .font(.caption)
                        .padding(.bottom)
                        .padding(.top, 8)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Upgrade")
            .alert(isPresented: $isShowingError, content: {
                Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("Okay")))
            })
        }
    }
    
    func buy(product: Product) async {
        do {
            if try await workoutManager.purchase(product: product) != nil {
                successClosingOfSheet()
            }
        } catch StoreError.failedVerification {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        } catch {
            print("Failed purchase for \(product.id). \(error)")
        }
    }
    
    func successClosingOfSheet() {
        withAnimation {
            wasPurchased = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showUpgradeView = false
        }
    }
}

#Preview {
    UpgradeView(workoutManager: WorkoutManager(), showUpgradeView: .constant(true))
}
