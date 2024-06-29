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
     
    var watch = false
    
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
                .foregroundColor(active ? .white : watch ? .black : .primary)
                .fontWeight(active ? .semibold : .regular)
                .fontDesign(active ? .rounded : .default)
        }
        .background(
            Capsule()
                .fill(active ? .accent : watch ? .secondary : .uiGray)
        )
        
    }
}

#Preview {
    SelectionButtonLabel(string: "#Mücke", chosenStrings: .constant(["Taube", "Karotten"]))
}
