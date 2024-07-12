//
//  UpgradeShowcase.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.07.2024.
//

import SwiftUI

struct UpgradeShowcase: View {
    var image: Image
    var title: String
    var subTitle: String
    var priceButton: String
    var backgroundColor: Color
    var buttonColor: Color
    var buttonTextColor: Color = .primary
    var fontColor: Color = .primary
    
    let buttonAction: () -> Void
    
    var body: some View {
        VStack {
            
            CircleImage(image: image)
                .padding()
            
            Text(title)
                .foregroundStyle(fontColor)
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 6)
            
            Text(subTitle)
                .foregroundStyle(fontColor)
            
            Button {
                buttonAction()
            } label: {
                Text(priceButton)
                    .font(.title3)
                    .fontWeight(.bold)
//                    .fontDesign(.rounded)
                    .foregroundStyle(buttonTextColor)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 10.0)
                            .fill(buttonColor)
                    )
            }
            .padding()

            
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25.0)
                .fill(backgroundColor)
        )
    }
}

#Preview {
    UpgradeShowcase(image: Image("poseidonGoat"), title: "Poseidon Goat", subTitle: "Be ready for the seven seas. Includes Future Features as: Crew Live Location Sharing.", priceButton: "$5.99 / Lifetime", backgroundColor: .darkBlue, buttonColor: .trackerGold, buttonTextColor: .black, fontColor: .white, buttonAction: { print("Button Pressed") })
        .padding()
}
