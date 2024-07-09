//
//  WatchUpgradShowcase.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 09.07.2024.
//

import SwiftUI

struct WatchUpgradShowcase: View {
    var image: Image
    var title: String
    var subTitle: String
    var priceButton: String
    var buttonColor: Color
    
    
    var body: some View {
        CircleImage(image: image)
            .padding()
        
        HStack {
            Spacer(minLength: 0.0)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            Spacer(minLength: 0.0)
        }
        
        Text(subTitle)
            .padding(.bottom, 8)
        
        Button {
            // get the in app purchase
        } label: {
            Text(priceButton)
        }
        .buttonStyle(.borderedProminent)
        .tint(buttonColor)
    }
}

#Preview {
    WatchUpgradShowcase(image: Image("kook"), title: "GOAT", subTitle: "Be ready for the seven seas.", priceButton: "$5.99 / Lifetime", buttonColor: .trackerGold)
}
