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
    let activity: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Group {
                HStack(alignment: .firstTextBaseline) {
                    Text(cutDate[0] + " " + cutDate[1])
                        .fontWeight(.bold)
                        .font(.title)
                    Text(cutDate[2])
                        .font(.body)
                    
                    Spacer()
                    
                    Text(activity)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.accent)
                        .textCase(nil)
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
    StatisticsMainHeader(cutDate: ["APR", "01", "2023"], locationName: "Magglingen", activity: "SUP DW Foil")
        .background {
            Color.gray.opacity(0.5)
        }
}
