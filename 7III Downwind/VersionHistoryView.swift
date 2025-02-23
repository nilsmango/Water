//
//  VersionHistoryView.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.02.2025.
//

import SwiftUI

struct VersionHistoryView: View {
    let versions: [Version] = versionHistory

    var body: some View {
        List {
            ForEach(versions, id: \.versionNumber) { version in
                Section {
                    VStack(alignment: .leading) {
                        Text(version.releaseDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 2)
                        
                        Text("Version \(version.versionNumber)")
                            .fontWeight(.bold)
                        
                        Text(version.introduction)
                            .lineLimit(nil)
                        
                        ForEach(version.changes, id: \.self) { change in
                            HStack(alignment: .top) {
                                Text("•")
                                    .fontWeight(.heavy)
                                Text(change)
                            }
                        }
                        .foregroundStyle(.primary)
                        
                    }
                    .padding(.vertical, 8)
                    
                }
            }
        }
        .navigationTitle("Water Version Log")
    }
}

#Preview {
    VersionHistoryView()
}
