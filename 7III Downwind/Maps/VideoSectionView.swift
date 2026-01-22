//
//  VideoSectionView.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import SwiftUI

struct VideoSectionView: View {
    @Binding var video: Video
    var onRemove: () -> Void
    
    var body: some View {
        HStack {
            TextField("Video URL", text: Binding(
                get: { video.url },
                set: { video = Video(id: video.id, url: $0, date: video.date) }
            ))
            .textFieldStyle(.roundedBorder)
            .keyboardType(.URL)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
