//
//  StatisticsMainHeader.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI

struct StatisticsMainHeader: View {
    let cutDate: [String]
    var locationName: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Group {
                HStack(alignment: .firstTextBaseline) {
                    Text(cutDate[0] + " " + cutDate[1])
                        .fontWeight(.bold)
                        .font(.title)
                    Text(cutDate[2])
                        .font(.body)
                }
                    .padding(.bottom, -12)
                Text(cutDate.dropFirst(3).joined(separator: " "))
                    .font(.body)
            }
            .padding(.bottom, 9)
            
            if locationName != "" {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.accent)
                    Text(locationName)
                }
                .textCase(nil)
                .font(.body)
                .padding(.bottom)
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    StatisticsMainHeader(cutDate: ["12312", "21323"], locationName: "Mage")
}
