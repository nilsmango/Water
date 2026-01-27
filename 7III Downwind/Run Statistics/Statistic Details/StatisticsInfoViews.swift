//
//  StatisticsInfoViews.swift
//  7III Location
//
//  Created by Simon Lang on 08.04.2024.
//

import SwiftUI

struct StatisticsInfoViews: View {
    var header: String
     var bodyText: String
     
     var body: some View {
         VStack(alignment: .leading) {
             Text(header)
                 .font(.caption)
             
             Text(bodyText)
                 .font(.body)
                 .foregroundColor(.primary)
         }
     }
}

struct StatisticsInfoViewsInteractive: View {
    let header: String
    let bodyText: String
    let alternateText: String
    let onTap: (() -> Void)?
    @State private var showAlternate = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(header)
                .font(.caption)
            
            Text(showAlternate ? alternateText : bodyText)
                .font(.body)
                .foregroundColor(.primary)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        showAlternate.toggle()
                        onTap?()
                    }
                }
        }
    }
}

#Preview {
    VStack {
        StatisticsInfoViews(header: "Time", bodyText: "2:02")
        StatisticsInfoViewsInteractive(header: "Fastest", bodyText: "3:45", alternateText: "20.1 km/h", onTap: nil)
    }
}
