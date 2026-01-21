//
//  RouteSticker.swift
//  7III Tracker
//
//  Created by Simon Lang on 26.06.2025.
//

import SwiftUI
import MapKit
import Photos

struct RouteSticker: View {
    @ObservedObject var downwindManager: DownwindManager
    let statisticsData: RunStatistic
    
    // Customizable properties
    @State private var showRoute = true
    @State private var routeInYellow = true
    @State private var showLocation = true
    @State private var showTags = true
    
    enum SecondStat: String, CaseIterable, Identifiable {
        case pace = "Pace"
        case topSpeed = "1s Top Speed"
        case turns = "Turns"

        var id: Self { self }
    }

    @State private var secondStat: SecondStat = .pace
    
    enum ThirdStat: String, CaseIterable, Identifiable {
        case time = "Time"
        case onFoil = "Time on Foil"
        case distance = "Max Distance on Foil"
        case popUps = "Pop-Ups"

        var id: Self { self }
    }

    @State private var thirdStat: ThirdStat = .time
    @State private var showHowTo = false
    @State private var showingSaveAlert = false
    
    
    // Route styling
    var lineWidth = 3.0
    let frameWidth = UIScreen.main.bounds.width
    
    // After testing, 6 seems to be the best bang for buck
    let upscalingFactor = 6.0
    
    
    var body: some View {
        ScrollView {
            VStack {
                ZStack {
                    Rectangle()
                        .fill(Color.gray)
                    
                    // Main sticker preview
                    stickerPreview
                        .frame(width: frameWidth, height: frameWidth * 1.7)
                        .background(Color.clear)
                        .id("StickerPreview") // For screenshot identification
                    
                    
                }
                
                
                // Toggle controls
               
                    Group {
                        Picker("Second Stat", selection: $secondStat) {
                            ForEach(SecondStat.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                            
                        Picker("Third Stat", selection: $thirdStat) {
                            ForEach(ThirdStat.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Toggle("Show Route", isOn: $showRoute)
                        if showRoute {
                            if statisticsData.locationString != nil && statisticsData.locationString != "" {
                                Toggle("Show Location", isOn: $showLocation)
                            }
                            
                            if statisticsData.tags != nil && !statisticsData.tags!.isEmpty {
                                Toggle("Show Tags", isOn: $showTags)
                            }
                            
                            Toggle("Route in Yellow", isOn: $routeInYellow)
                        }
                    }
                    .tint(.accent)
                    .padding(.horizontal)
                    .padding(.top)
                
                
                
                // Save button
                HStack {
                    // Sharing does not really work for me.
//                    Button {
//                        shareSticker()
//                    } label: {
//                        Label("Share", systemImage: "square.and.arrow.up")
//                    }
                    
                    
                    Button {
                        saveSticker()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        showHowTo = true
                    } label: {
                        Label("How to Use", systemImage: "info.circle")
                    }
                    .buttonStyle(.bordered)
                }
                
                .padding()
            }
            
            
        }
        .alert("Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The image has been saved to your photo library.")
        }
        .sheet(isPresented: $showHowTo, content: {
            NavigationStack {
                StickerHowToView()
                .navigationTitle("How to Use")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showHowTo = false
                        }, label: {
                            XMarkLabel()
                        })
                    }
                }
            }
            
        })
    }
    
    @ViewBuilder
    private var stickerPreview: some View {
        ZStack {
            VStack(spacing: 0) {
                
                upperStatsOverlay
                    .padding(.top, 32)
                
                Spacer(minLength: 0.0)
                
                // Route visualization
                if showRoute && !statisticsData.locationData.isEmpty {
                    routeCanvas
                        .frame(width: frameWidth, height: frameWidth * 0.7)
                }
                
                location
                
                Spacer(minLength: 0.0)
                
                logo
                    .padding(.bottom, 32)
            }
        }
        .frame(width: frameWidth, height: frameWidth * 1.7)
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var routeCanvas: some View {
        Canvas { context, size in
            guard !statisticsData.locationData.isEmpty else { return }
            
            let coordinates = makeCoordinates(from: statisticsData)
            let bounds = calculateBounds(coordinates: coordinates)
            let padding: Double = 16
            
            // Convert coordinates to canvas points
            var path = Path()
            var points: [CGPoint] = []
            
            for (index, coordinate) in coordinates.enumerated() {
                let point = convertToCanvasPoint(
                    coordinate: coordinate,
                    bounds: bounds,
                    canvasSize: size,
                    padding: padding
                )
                points.append(point)
                
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            
            // Draw the route path
            context.stroke(
                path,
                with: routeInYellow ? .color(.neonYellow) : .color(.white),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

        }
    }
    
    
    @ViewBuilder
    private var upperStatsOverlay: some View {
        VStack(spacing: 8) {
                VStack(spacing: 8) {
                        StatisticRow(
                            value: makePrettyDistance(meters: statisticsData.runDistance, system: downwindManager.measurementSystem, statistics: true),
                            label: statisticsData.workoutType?.prettyString ?? "Distance"
                        )
                    
                    
                    StatisticRow(
                        value: {
                            switch secondStat {
                            case .pace:
                                downwindManager.calculateAveragePace(statistic: statisticsData)
                            case .topSpeed:
                                makePrettySpeed(speed: statisticsData.topSpeed1s, system: downwindManager.measurementSystem)
                            case .turns:
                                String(statisticsData.turnsCount ?? 0)
                            }
                        }(),
                        label: secondStat.rawValue
                    )
                    
                    StatisticRow(
                        value: {
                            switch thirdStat {
                            case .time:
                                makePrettyTime(timeInMinutes: statisticsData.runTime)
                            case .onFoil:
                                String(format: "%.1f", statisticsData.percentageOnFoil ?? 0) + " %"
                            case .popUps:
                                String(statisticsData.popUps ?? 0)
                            case .distance:
                                makePrettyDistance(meters: statisticsData.longestDistanceOnFoil ?? 0, system: downwindManager.measurementSystem, statistics: true)
                            }
                        }(),
                        label: thirdStat.rawValue
                    )
                    
                }
                .foregroundStyle(.white)
//                .shadow(color: .black.opacity(0.4),radius: 5)
            
        }
    }
    
    @ViewBuilder
    private var logo: some View {
                Text("7III Water")
                    .foregroundStyle(.white)
                    .font(.title)
                    .fontWeight(.bold)
//                    .shadow(color: .black.opacity(0.4),radius: 5)
    }
    
    @ViewBuilder
    private var location: some View {

                if statisticsData.locationString != nil && statisticsData.locationString != "" && showLocation && showRoute {
                    VStack(spacing: 4) {
                        HStack {
//                        Image(systemName: "location.fill")
                            Text(statisticsData.locationString!)
                        }
//                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
//                        .shadow(color: .black.opacity(0.4),radius: 5)

                        if let tags = statisticsData.tags, !tags.isEmpty && showTags {
                            Text(tags.joined(separator: " "))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }

    }
    
    // Helper functions
    private func makeCoordinates(from statistic: RunStatistic) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D]()
        for location in statistic.locationData {
            let locationCoordinates = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            coordinates.append(locationCoordinates)
        }
        return coordinates
    }
    
    private func calculateBounds(coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else { return (0, 0, 0, 0) }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        return (minLat, maxLat, minLon, maxLon)
    }
    
    private func convertToCanvasPoint(
        coordinate: CLLocationCoordinate2D,
        bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double),
        canvasSize: CGSize,
        padding: Double = 40
    ) -> CGPoint {
        let lonRange = bounds.maxLon - bounds.minLon
        let latRange = bounds.maxLat - bounds.minLat
        
        // Ensure minimum range to avoid division by zero
        let adjustedLonRange = max(lonRange, 0.001)
        let adjustedLatRange = max(latRange, 0.001)
        
        // Calculate available canvas space (minus padding)
        let availableWidth = canvasSize.width - (2 * padding)
        let availableHeight = canvasSize.height - (2 * padding)
        
        // Calculate scale factors for both dimensions
        let scaleX = availableWidth / adjustedLonRange
        let scaleY = availableHeight / adjustedLatRange
        
        // Use the smaller scale factor to maintain aspect ratio
        let uniformScale = min(scaleX, scaleY)
        
        // Calculate the actual dimensions the route will occupy
        let scaledWidth = adjustedLonRange * uniformScale
        let scaledHeight = adjustedLatRange * uniformScale
        
        // Center the route in the available space
        let offsetX = (availableWidth - scaledWidth) / 2
        let offsetY = (availableHeight - scaledHeight) / 2
        
        // Convert coordinate to normalized position (0-1)
        let normalizedX = (coordinate.longitude - bounds.minLon) / adjustedLonRange
        let normalizedY = (coordinate.latitude - bounds.minLat) / adjustedLatRange
        
        // Convert to canvas coordinates with uniform scaling and centering
        let x = padding + offsetX + (normalizedX * scaledWidth)
        let y = canvasSize.height - (padding + offsetY + (normalizedY * scaledHeight)) // Flip Y axis
        
        return CGPoint(x: x, y: y)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    
    @MainActor
    private func saveSticker() {
        let renderer = ImageRenderer(content: stickerPreview)
        renderer.scale = upscalingFactor
        
        // Configure renderer for transparency
//        renderer.opaque = false
        renderer.colorMode = .nonLinear
        
        if let image = renderer.uiImage {
            // Convert to PNG data to preserve transparency
            if let pngData = image.pngData() {
                // Create a temporary file URL for the PNG
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("sticker_\(UUID().uuidString).png")
                
                do {
                    try pngData.write(to: tempURL)
                    
                    // Save to Photos using PHPhotoLibrary for better format control
                    PHPhotoLibrary.requestAuthorization { status in
                        if status == .authorized {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetCreationRequest.forAsset().addResource(
                                    with: .photo,
                                    fileURL: tempURL,
                                    options: nil
                                )
                            }) { success, error in
                                DispatchQueue.main.async {
                                    // Clean up temp file
                                    try? FileManager.default.removeItem(at: tempURL)
                                    
                                    if success {
                                        self.showingSaveAlert = true
                                    } else {
                                        print("Failed to save sticker: \(error?.localizedDescription ?? "Unknown error")")
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    print("Failed to write PNG data: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func shareSticker() {
        let renderer = ImageRenderer(content: stickerPreview)
        renderer.scale = upscalingFactor
        renderer.colorMode = .nonLinear
        
        if let image = renderer.uiImage {
            // Convert to PNG data to preserve transparency
            if let pngData = image.pngData() {
                // Create a temporary file URL for the PNG
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("sticker_\(UUID().uuidString).png")
                
                do {
                    try pngData.write(to: tempURL)
                    
                    // Create activity items for sharing
                    let activityItems: [Any] = [tempURL, image]
                    
                    // Create activity view controller
                    let activityVC = UIActivityViewController(
                        activityItems: activityItems,
                        applicationActivities: nil
                    )
                    
                    // Exclude activities that don't make sense for stickers
                    activityVC.excludedActivityTypes = [
                        .addToReadingList,
                        .assignToContact,
                        .openInIBooks,
                        .print
                    ]
                    
//                    // Configure for iPad
//                    if let popover = activityVC.popoverPresentationController {
//                        // You'll need to set this to your share button or view
//                        popover.sourceView = self.view // Replace with your actual source view
//                        popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
//                        popover.permittedArrowDirections = []
//                    }
                    
                    // Present the share sheet
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        
                        // Find the topmost view controller
                        var topVC = rootVC
                        while let presentedVC = topVC.presentedViewController {
                            topVC = presentedVC
                        }
                        
                        topVC.present(activityVC, animated: true) {
                            // Clean up temp file after a delay to ensure sharing completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                                try? FileManager.default.removeItem(at: tempURL)
                            }
                        }
                    }
                    
                } catch {
                    print("Failed to write PNG data for sharing: \(error)")
                }
            }
        }
    }
}

struct StatisticRow: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 0) {
            Text(label)
//                .font(.footnote)
//                .fontWeight(.bold)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
        }
    }
}






#Preview {
    RouteSticker(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 20000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: ["#swim", "#wakeboard", "#fun"], locationString: "Concise → St Blaise"))
}
