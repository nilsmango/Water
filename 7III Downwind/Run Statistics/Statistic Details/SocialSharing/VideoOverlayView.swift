//
//  VideoOverlayView.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.07.2024.
//

import SwiftUI
import AVFoundation
import AVKit

struct VideoOverlayView: View {
    @ObservedObject var downwindManager: DownwindManager
    var statisticsData: RunStatistic
    
    @State private var showLocation = true
    @State private var showTopSpeed = true
    @State private var showAverageSpeed = true
    @State private var speedSelection: SpeedOption = .speed
    @State private var instagramReel = false
    @State private var showTurns = false
    
    @State private var selectedVideo: URL?
    @State private var showVideoPicker = false
    @State private var processedVideo: URL?
    @State private var isProcessing = false
    @State private var showShareSheet = false
    @State private var error: Error?
    
    private var hasDistance: Bool { statisticsData.runDistance > 0 }
    
    var body: some View {
//        ScrollView {
            VStack {
                HStack {
                    Text("Overlay")
                        .font(.headline)
                    Spacer()
                }
                
                ShareVideoOverlay(
                    sport: statisticsData.workoutType?.prettyString ?? "Surfing",
                    distance: hasDistance ? makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true) : String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal",
                    time: makePrettyTime(timeInMinutes: statisticsData.runTime),
                    extraTitle: hasDistance ? speedSelection.rawValue : "∅-Heart Rate",
                    extraValue: hasDistance ? speedSelection == .speed ?
                    makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) :
                        downwindManager.calculateAveragePace(statistic: statisticsData) : String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm",
                    topSpeedValue: hasDistance ? showTopSpeed ? makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem) : nil : nil,
                    showAverageSpeed: hasDistance ? showAverageSpeed : true,
                    scale: 0.9,
                    showLocation: showLocation,
                    locationName: statisticsData.locationString,
                    instagramReel: instagramReel,
                    showTurns: showTurns,
                    turnsTitle: "Turns",
                    turnsValue: statisticsData.turnsCount == 0 || statisticsData.turnsCount == nil ? "-" : String(statisticsData.turnsCount!)
                )
                .frame(width: UIScreen.main.bounds.width - 32)
                .padding(.vertical, 8)
                .padding(.top, instagramReel ? 0 : 40)
                .padding(.bottom, instagramReel ? 40 : 0)
                .background {
                    RoundedRectangle(cornerRadius: 10.0)
                        .fill(Gradient(colors: [.blue, .accent]))
                }
                
                Group {
                    if statisticsData.locationString != nil {
                        Toggle("Show Location", isOn: $showLocation)
                            .tint(.accent)
                    }
                    if hasDistance {
                        Toggle("Show Turns", isOn: $showTurns).tint(.accent)
                        Toggle("Show Average", isOn: $showAverageSpeed).tint(.accent)
                        if showAverageSpeed {
                            Picker("∅-Speed Format", selection: $speedSelection) {
                                ForEach(SpeedOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        Toggle("Show Top Speed", isOn: $showTopSpeed).tint(.accent)
                    }
                    
                    Toggle("Top Placement (Instagram Reels)", isOn: $instagramReel).tint(.accent)
                    
                }
                .padding(.top, 8)
                
                HStack {
                    Text("Video")
                        .font(.headline)
                    Spacer()
                }
                .padding(.top)
                
                Group {
                    
                    if let videoURL = selectedVideo {
                        HStack {
                            VideoPlayer(player: AVPlayer(url: videoURL))
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .clipped()
                                .clipShape(Circle())
                                .disabled(true)
                                .overlay {
                                    Image(systemName: isProcessing ? "gearshape.arrow.triangle.2.circlepath" : "checkmark")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 50, height: 50)
                                                        .foregroundColor(.white)
                                                        .shadow(color: .black.opacity(0.5), radius: 5)
                                }
                            
                            Spacer(minLength: 0.0)
                            
                            VStack(alignment: .leading) {
                                if isProcessing {
                                    ProgressView("Processing Video")
                                    Text("This might take some time, please be patient!")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                } else if processedVideo != nil {
                                    Button {
                                        processedVideo = nil
                                        selectedVideo = nil
                                        showVideoPicker = true
                                    } label: {
                                        Label("New Video", systemImage: "arrow.counterclockwise")
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button {
                                        showShareSheet = true
                                    } label: {
                                        Label("Share Video", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button {
                                        selectedVideo = nil
                                        showVideoPicker = true
                                    } label: {
                                        Label("Other Video", systemImage: "arrow.counterclockwise")
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button {
                                        Task {
                                            await processVideo()
                                            showShareSheet = true
                                        }
                                    } label: {
                                        Label("Add Overlay", systemImage: "film.stack")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                            
                        
                    } else {
                        Button {
                            showVideoPicker = true
                        } label: {
                            Label("Select Video", systemImage: "film")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 8)
                
                Spacer()
            }
            .padding(.horizontal, 32)
//        }
        
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
                distance: hasDistance ? makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true) : String(Int(statisticsData.kCalories?.rounded() ?? 0)) + " kcal",
                time: makePrettyTime(timeInMinutes: statisticsData.runTime),
                extraTitle: hasDistance ? speedSelection.rawValue : "∅-Heart Rate",
                extraValue: hasDistance ? speedSelection == .speed ?
                makePrettySpeed(speed: statisticsData.averageSpeed ?? (statisticsData.runDistance / 1000) / (statisticsData.runTime / 60), system: downwindManager.measurementSystem) :
                    downwindManager.calculateAveragePace(statistic: statisticsData) : String(Int(statisticsData.averageHeartRate?.rounded() ?? 0)) + " bpm",
                topSpeedValue: hasDistance ? showTopSpeed ? makePrettySpeed(speed: statisticsData.topSpeed, system: downwindManager.measurementSystem) : nil : nil,
                showAverageSpeed: hasDistance ? showAverageSpeed : true,
                showLocation: showLocation,
                locationName: statisticsData.locationString, 
                instagramReel: instagramReel,
                showTurns: showTurns,
                turnsTitle: "Turns",
                turnsValue: statisticsData.turnsCount == 0 || statisticsData.turnsCount == nil ? "-" : String(statisticsData.turnsCount!)
            )
        } catch {
            self.error = error
        }
        isProcessing = false
    }
}

#Preview {
    VideoOverlayView(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 0, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: []))
}
