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

#Preview {
    StatisticsInfoViews(header: "Time", bodyText: "2:02")
}
