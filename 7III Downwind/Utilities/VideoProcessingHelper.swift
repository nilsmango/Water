//
//  VideoProcessingHelper.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.07.2024.
//

import AVFoundation
import SwiftUI

struct VideoProcessingHelper {
    static func processVideoWithOverlay(
        videoURL: URL,
        sport: String,
        distance: String,
        time: String,
        extraTitle: String,
        extraValue: String,
        topSpeedValue: String?,
        showAverageSpeed: Bool,
        showLocation: Bool,
        locationName: String?,
        instagramReel: Bool
    ) async throws -> URL {
        let composition = AVMutableComposition()
        
        // Setup video track
        guard let sourceVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoProcessingError.failedToAddVideoTrack
        }
        
        // Setup audio track
        let sourceAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw VideoProcessingError.failedToLoadVideo
        }
        
        try sourceVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                             of: videoTrack,
                                             at: .zero)
        
        if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
            try sourceAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                                  of: audioTrack,
                                                  at: .zero)
        }
        
        // Get the video orientation
        let videoSize = sourceVideoTrack.naturalSize
        let transform = try await videoTrack.load(.preferredTransform)
        let videoIsPortrait = transform.a == 0 && transform.d == 0
        let displaySize = videoIsPortrait ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
        
        // FIXME: These layers should actually for the height get measured with a .background(.clear) geometry reader. But this is good enough for now.
        // Create overlay layer
        let overlaySize = CGSize(width: displaySize.width * 0.9, height: displaySize.width * 0.9 * (showLocation && locationName != nil ? Constants.previewContainerHeightMultipleLocation : Constants.previewContainerHeightMultiple))
        
        let overlayOrigin = CGPoint(x: displaySize.width * 0.05, y: instagramReel ? displaySize.height - (overlaySize.height * 1.7) : 6)
        
        let overlayView = ShareVideoOverlay(
            sport: sport,
            distance: distance,
            time: time,
            extraTitle: extraTitle,
            extraValue: extraValue,
            topSpeedValue: topSpeedValue,
            showAverageSpeed: showAverageSpeed,
            scale: overlaySize.width / Constants.previewContainerWidth,
            showLocation: showLocation,
            locationName: locationName,
            instagramReel: instagramReel
        )
        
        let overlayImage = try await renderOverlay(overlayView, size: overlaySize)
        
        let overlayLayer = CALayer()
        overlayLayer.contents = overlayImage.cgImage
        overlayLayer.frame = CGRect(origin: overlayOrigin, size: overlaySize)
        overlayLayer.opacity = 1.0
        
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: displaySize)
        
        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: displaySize)
        outputLayer.addSublayer(videoLayer)
        outputLayer.addSublayer(overlayLayer)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = displaySize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: outputLayer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: sourceVideoTrack)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Setup export session
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.failedToCreateExportSession
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("processedVideo_\(UUID().uuidString).mp4")
        
        export.videoComposition = videoComposition
        export.outputURL = outputURL
        export.outputFileType = .mp4
        
        await export.export()
        
        guard export.status == .completed else {
            throw VideoProcessingError.exportFailed(export.error)
        }
        
        return outputURL
    }
    
    @MainActor
    private static func renderOverlay(_ overlayView: ShareVideoOverlay, size: CGSize) async throws -> UIImage {
        let renderer = ImageRenderer(content: overlayView.frame(width: size.width, height: size.height))
        renderer.scale = 1.0 // Adjust for sharpness
        
        guard let overlayImage = renderer.uiImage else {
            throw VideoProcessingError.failedToRenderOverlay
        }
        
        return overlayImage
    }
}




enum VideoProcessingError: Error {
    case failedToAddVideoTrack
    case failedToLoadVideo
    case failedToRenderOverlay
    case failedToCreateExportSession
    case exportFailed(Error?)
}
