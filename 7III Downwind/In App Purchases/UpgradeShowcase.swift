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
    var price: String
    var color: Color
    
    
    var body: some View {
        VStack {
            
            CircleImage(image: image)
                .padding()
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(subTitle)
            
            Text(price)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    Capsule()
                        .fill(color.blendMode(.multiply))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25.0)
                .fill(color)
        )
    }
}

#Preview {
    UpgradeShowcase(image: Image("poseidonGoat"), title: "Poseidon Goat", subTitle: "Be ready for the seven seas. Includes Future Features as: Crew Live Location Sharing.", price: "$ 5.99", color: .trackerGold)
        .padding()
}
