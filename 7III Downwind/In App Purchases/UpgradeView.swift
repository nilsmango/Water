//
//  UpgradeView.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.07.2024.
//

import SwiftUI
import StoreKit

struct UpgradeView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showUpgradeView: Bool

    @State private var selection: Tab = .poseidon
    @State private var isShowingError = false
    @State private var errorTitle = ""
    @State private var wasPurchased = false
    
    enum Tab {
        case poseidon, weekend, kook
        
        var color: Color {
            switch self {
            case .poseidon:
                return .darkBlue 
            case .weekend:
                return .warriorSky
            case .kook:
                return .kookSea
            }
        }
    }
    
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
        if downwindManager.unableToLoadProducts {
            VStack {
                Text("Unable to load products.")
                Text("If you are offline, try again when online.")
                Button("Try Again") {
                    Task {
                        await downwindManager.loadProductIdentifiersAndRequestProducts()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Early Adopter Offer")
            
        } else {
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
                        .padding(.horizontal, 8)
                        //                    .background(
                        //                        RoundedRectangle(cornerRadius: 8.0)
                        //                            .fill(selection.color)
                        //                    )
                        .padding(.horizontal)
                    }
                    
                    Text("")
                    
                    if downwindManager.premiumProducts.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Loading Products")
                            Spacer()
                        }
                        .frame(height: 250)
//                        .onAppear {
//                            Task {
//                                await downwindManager.loadProductIdentifiersAndRequestProducts()
//                            }
//                            
//                        }
                        
                    } else {
                        TabView(selection: $selection) {
                            
                            if let goatProduct = downwindManager.premiumProducts.first(where: { $0.id == "com.project7iii.tracker.goat"}) {
                                UpgradeShowcase(image: Image("poseidonGoat"), title: goatProduct.displayName, subTitle: goatProduct.description,
                                                priceButton: "\(goatProduct.displayPrice) / Lifetime", backgroundColor: .darkBlue, buttonColor: .trackerGold, buttonTextColor: .primary, makeLabel: wasPurchased) { Task {
                                    await buy(product: goatProduct)
                                }}
                                    .padding()
                                    .tag(Tab.poseidon)
                            }
                            
                            if let weekendWarriorProduct = downwindManager.premiumProducts.first(where: { $0.id == "com.project7iii.tracker.weekend_warrior"}) {
                                UpgradeShowcase(image: Image("weekendWarrior"), title: weekendWarriorProduct.displayName, subTitle: weekendWarriorProduct.description, priceButton: "\(weekendWarriorProduct.displayPrice) / Year", backgroundColor: .warriorSky, buttonColor: .kookSea, buttonTextColor: .primary, makeLabel: wasPurchased) { Task {
                                    await buy(product: weekendWarriorProduct)
                                }}
                                    .padding()
                                    .tag(Tab.weekend)
                            }
                            
                            if let kookProduct = downwindManager.premiumProducts.first(where: { $0.id == "com.project7iii.tracker.kook"}) {
                                UpgradeShowcase(image: Image("kook"), title: kookProduct.displayName, subTitle: kookProduct.description, priceButton: "\(kookProduct.displayPrice) / Month", backgroundColor: .kookSea, buttonColor: .warriorSky, buttonTextColor: .primary, makeLabel: wasPurchased) { Task {
                                    await buy(product: kookProduct)
                                }}
                                    .padding()
                                    .tag(Tab.kook)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle())
                        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                        .frame(height: 620)
                        .padding(.top, -50.0)
                    }                    
                    
                    VStack {
                        Button {
                            // TODO: redeem code
                        } label: {
                            Text("Redeem Code")
                                .fontWeight(.bold)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule()
                                        .fill(selection.color)
                                        .animation(.default, value: selection.color)
                                )
                            
                        }
                        .tint(.primary)
                        //                .padding(.top)
                                                
                        HStack {
                            Spacer()
                            Text("[Terms & Conditions](https://project7iii.com/tracker/terms-and-conditions/) and [Privacy Policy](https://project7iii.com/tracker/privacy-policy/)")
                            Spacer()
                        }
                        .font(.caption)
                        //                        .padding([.bottom, .horizontal])
                        .padding(.top, 32)
                    }
                    
                    
                    
                    Text("Note: If you are unable to afford an upgrade, please email us at tracker@project7iii.com for a coupon code.")
                    
                        .font(.caption)
                        .padding([.bottom, .horizontal])
                        .padding(.top, 8)
                }
                .padding(.horizontal)
            }
//        .background(
//            .gray.opacity(0.4)
//        )
        .navigationTitle("Early Adopter Offer")
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("Okay")))
        })
        }
    }
    
    func buy(product: Product) async {
        do {
            if try await downwindManager.purchase(product: product) != nil {
                withAnimation {
                    wasPurchased = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showUpgradeView = false
                }
            }
        } catch StoreError.failedVerification {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        } catch {
            print("Failed purchase for \(product.id). \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        UpgradeView(downwindManager: DownwindManager(), showUpgradeView: .constant(true))
    }
}
