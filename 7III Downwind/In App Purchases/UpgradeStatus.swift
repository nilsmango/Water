//
//  UpgradeStatus.swift
//  7III Tracker
//
//  Created by Simon Lang on 15.07.2024.
//

import SwiftUI

struct UpgradeStatus: View {
    var displayName: String?
    var image: Image
    var nextBilling: String
    
    var body: some View {
        HStack {
            CircleImage(image: image, shadow: false)
                .frame(height: 75)
            
            VStack(alignment: .leading) {
                Text("Status:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Text(displayName ?? "Unknown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(nextBilling)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            
        }
    }
}

#Preview {
    List {
        UpgradeStatus(displayName: "Weekend Warrior", image: Image("poseidonGoat"), nextBilling: "Next billing date: 12.12.23")
    }
    
}
