//
//  ShareStatisticsView.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI
import PhotosUI

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareStatisticsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var statisticsData: RunStatistic
    
    @State private var useMap = true
    @State private var showAverageSpeed = true
    @State private var speedSelection: SpeedOption = .speed
    @State private var topSpeedSelection: TopSpeedOption = .top1
    
    @State private var showTopSpeed = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var previewUIView = UIView()
    @State private var shareImage: UIImage?
    @State private var showImageShareSheet: IdentifiableImage?
    @State private var showingSaveAlert = false
    let imageSaver = ImageSaver()
    @State private var scale: Double = 1.0
    @State private var showLocation = true
    
    @State private var showPopUps = false
    @State private var showTimeOnFoil = false
    @State private var showMaxDistanceOnFoil = false
    @State private var showTurns = false
    
    @State private var showCalories = false
    @State private var showHeartRate = false
    @State private var showTags = true
    @State private var offset = -8.0
    let fullScreen = true
    
    var body: some View {
        ScrollView {
            SharePreviewWrapper(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showingSpeedInsteadPace: speedSelection == .speed ? true : false, showTopSpeed: showTopSpeed, topSpeedSelection: topSpeedSelection, showAverageSpeed: showAverageSpeed, scale: scale, locationName: statisticsData.locationString, showLocation: showLocation, showCalories: showCalories, showHeartRate: showHeartRate, showPopUps: showPopUps, showTimeOnFoil: showTimeOnFoil, showMaxDistanceOnFoil: showMaxDistanceOnFoil, showTurns: showTurns, fullScreen: fullScreen, showTags: showTags, offset: $offset) { view in
                self.previewUIView = view
            }
            .frame(width: UIScreen.main.bounds.width, height: fullScreen ? UIScreen.main.bounds.width * 1.7777777777777777 : UIScreen.main.bounds.width)
            .onChange(of: offset) { oldValue, newValue in
                if oldValue >= -8.0 && newValue < -8.0 {
                    if scale > 0.7 {
                        scale = 0.7
                    }
                }
            }
            .onChange(of: fullScreen) { oldValue, newValue in
                if !fullScreen {
                    offset = -8.0
                } else {
                    offset = 0.0
                }
            }
            
            if useMap {
                if !fullScreen {
                    Label("You can adjust the map window", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            
            OverlaySettingsView(
                        scale: $scale,
                        showLocation: $showLocation,
                        showAverageSpeed: $showAverageSpeed,
                        speedSelection: $speedSelection,
                        showTopSpeed: $showTopSpeed,
                        topSpeedSelection: $topSpeedSelection,
                        showPopUps: $showPopUps,
                        showTimeOnFoil: $showTimeOnFoil, showMaxDistanceOnFoil: $showMaxDistanceOnFoil,
                        showTurns: $showTurns,
                        showCalories: $showCalories,
                        showHeartRate: $showHeartRate,
                        showTags: $showTags,
                        useMap: $useMap,
                        showImagePicker: $showImagePicker,
                        showCamera: $showCamera,
                        statisticsData: statisticsData
                    )
            
            HStack {
                Button {
                    showImageShareSheet = IdentifiableImage(image: captureImage())
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    saveImageToPhotoLibrary()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .onAppear {
                if fullScreen {
                    offset = 0.0
                }
            }
            
        }
        
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
        }
        .sheet(item: $showImageShareSheet, content: { item in
            ActivityViewController(activityItems: [item.image])
        })
        .alert("Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The image has been saved to your photo library.")
        }
    }
    
    private func captureImage(asJPEG: Bool = false) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: previewUIView.bounds.size)
        let capturedImage = renderer.image { _ in
            previewUIView.drawHierarchy(in: previewUIView.bounds, afterScreenUpdates: true)
        }
        if asJPEG {
            if let jpegData = capturedImage.jpegData(compressionQuality: 0.9) {
                    return UIImage(data: jpegData) ?? capturedImage
                }
        }
        
        return capturedImage
    }
    
    private func saveImageToPhotoLibrary() {
            let image = captureImage()
            imageSaver.writeToPhotoAlbum(image: image)
            showingSaveAlert = true
        }
}

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving image: \(error.localizedDescription)")
        } else {
            // print("Image saved successfully")
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ShareStatisticsView(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: ["#swim", "#wakeboard", "#fun"]))
}
