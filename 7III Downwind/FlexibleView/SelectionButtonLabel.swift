//
//  TagsOrIngredientButtonLabel.swift
//  7III Recipes
//
//  Created by Simon Lang on 29.11.23.
//

import SwiftUI

 struct SelectionButtonLabel: View {
    var string: String
    
    @Binding var chosenStrings: [String]

    var allStrings: [String]
    
    var body: some View {
        let active = chosenStrings.contains(string)
        
        ZStack {
            // a little clear text trickery so the button stays the same width no matter the font weight
            Text(string)
                .foregroundColor(.clear)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(8)
            
            Text(string)
                .foregroundColor(active ? .white : .primary)
                .fontWeight(active ? .semibold : .regular)
                .fontDesign(active ? .rounded : .default)
        }
        .background(
            Capsule()
                .fill(active ? .accent : .gray.opacity(0.5))
        )
        
    }
}

#Preview {
    SelectionButtonLabel(string: "Mücke", chosenStrings: .constant(["Taube", "Karotten"]), allStrings: ["Taube", "Mücke", "Karotten"])
}
