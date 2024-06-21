//
//  TagsFlexiView.swift
//  7III Location
//
//  Created by Simon Lang on 09.04.2024.
//

import SwiftUI

struct TagsFlexiView: View {
    var strings: [String]
    
    var body: some View {
        if strings.isEmpty {
            EmptyTagsView()
        } else {
            FlexibleView(
                data: strings,
                spacing: 5,
                alignment: .leading
            ) { string in
                    Text(string)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .padding(8)
                        .background(
                            Capsule()
                                .fill(.accent)
                            
                        )
                }
        }
        
    }
}

#Preview {
    TagsFlexiView(strings: ["#140p", "#badWeather"])
}
