//
//  NewsSection.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.02.2025.
//

import SwiftUI

struct NewsSection: View {
    @ObservedObject var downwindManager: DownwindManager
    
    let version: Version = versionHistory.first!
    
    var body: some View {
            VStack(alignment: .leading) {
                
                Text("Welcome to 7III Water Version \(version.versionNumber)")
                    .font(.subheadline)
                //                            .foregroundStyle(.secondary)
                    .padding(.bottom, 3)
                
                Text("What's New?")
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
                
                HStack {
                    Spacer()
                    Button(action: {
                        downwindManager.lastVersionNewsClosed = downwindManager.currentAppVersion
                    }) {
                        Label("Remove News", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    Spacer()
                }
                .padding(.top, 8)
                
            }
            .padding()
            .background {
                ListBackground(special: true)
            }
    }
}

#Preview {
    VStack {
        NewsSection(downwindManager: DownwindManager())
            .padding()
        Spacer()
    }
        .background {
            Rectangle()
                .ignoresSafeArea()
                .foregroundStyle(.listBackground)
        }
    
}

