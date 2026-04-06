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
    var headerBadgeText: String? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 6) {
                Text(header)
                    .font(.caption)
                
                if let headerBadgeText {
                    BetaBadgeView(text: headerBadgeText)
                }
            }
            
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
                        showAlternate.toggle()
                        onTap?()
                }
        }
    }
}

#Preview {
    VStack {
        BetaBadgeView()
        StatisticsInfoViews(header: "Time", bodyText: "2:02")
        StatisticsInfoViewsInteractive(header: "Fastest", bodyText: "3:45", alternateText: "20.1 km/h", onTap: nil)
    }
}
