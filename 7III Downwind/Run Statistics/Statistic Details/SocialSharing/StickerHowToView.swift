//
//  StickerHowToView.swift
//  7III Tracker
//
//  Created by Simon Lang on 27.06.2025.
//

import SwiftUI

struct StickerHowToView: View {
        var steps = [
                "Save the sticker to camera roll.",
                "In Instagram load your background video or image to start a story or a reel.",
                "Tap the Sticker Symbol (Square Smiley Face).",
                "Tap Photo Sticker.",
                "Select the sticker from your camera roll.",
                "Adjust the size of the sticker to fit your story. The sticker will not be 100% opacity, if you also add a music sticker it should get solid again. If you are in a reel you can't make the sticker bigger without it getting pixelated unfortunately. We also did not find a way to make it solid there."
            ]
            
            var body: some View {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(steps.indices, id: \.self) { i in
                            Text("\(i + 1). \(steps[i])")
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }

#Preview {
    StickerHowToView()
}
