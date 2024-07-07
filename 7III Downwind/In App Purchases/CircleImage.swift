//
//  CircleImage.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.07.2024.
//

import SwiftUI

struct CircleImage: View {
    var image: Image
    
    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(
//                RoundedRectangle(cornerRadius: 25.0)
                Circle()
            )
//            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(radius: 7)
            
    }
}

#Preview {
    CircleImage(image: Image("poseidonGoat"))
}
