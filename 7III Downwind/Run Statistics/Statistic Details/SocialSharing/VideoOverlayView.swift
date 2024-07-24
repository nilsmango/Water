//
//  VideoOverlayView.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.07.2024.
//

import SwiftUI

import SwiftUI
import AVFoundation
import AVKit

struct VideoOverlayView: View {
    @ObservedObject var downwindManager: DownwindManager
    var statisticsData: RunStatistic
    
    @State private var showingSpeedInsteadPace = true
    @State private var showTopSpeed = true
    @State private var showAverageSpeed = true
    
    @State private var selectedVideo: URL?
    @State private var showVideoPicker = false
    @State private var processedVideo: URL?
    @State private var isProcessing = false
    @State private var showShareSheet = false
    @State private var error: Error?
    
    var body: some View {
        VStack {
            if let videoURL = selectedVideo {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
                
                if isProcessing {
                    ProgressView("Processing video...")
                } else if processedVideo != nil {
                    Button("Share Processed Video") {
                        showShareSheet = true
                    }
                } else {
                    Button("Add Overlay and Process") {
                        Task {
                            await processVideo()
                            showShareSheet = true
                        }
                        
                    }
                }
            } else {
                Button("Select Video") {
                    showVideoPicker = true
                }
            }
        }
        
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(selectedVideo: $selectedVideo)
        }
        
        .sheet(isPresented: $showShareSheet) {
            if let url = processedVideo {
                ActivityViewController(activityItems: [url])
            }
        }
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        })
    }
    
    func processVideo() async {
        guard let videoURL = selectedVideo else { return }
        isProcessing = true
        do {
            processedVideo = try await VideoProcessingHelper.processVideoWithOverlay(
                videoURL: videoURL,
                sport: statisticsData.workoutType?.prettyString ?? "Surfing",
                distance: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true),
                time: makePrettyTime(timeInMinutes: statisticsData.runTime),
                extraTitle: showingSpeedInsteadPace ? "∅-Speed" : "∅-Pace",
                extraValue: showingSpeedInsteadPace ?
                makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) :
                downwindManager.calculateAveragePace(statistic: statisticsData),
                topSpeedValue: showTopSpeed ? makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem) : nil,
                showAverageSpeed: showAverageSpeed
            )
        } catch {
            self.error = error
        }
        isProcessing = false
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideo: URL?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.selectedVideo = videoURL
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    VideoOverlayView(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: []))
}
