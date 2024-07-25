//
//  ShareStatisticsView.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI
import PhotosUI

struct ShareStatisticsView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    var statisticsData: RunStatistic
    
    @State private var useMap = true
    @State private var showAverageSpeed = true
    @State private var speedSelection: SpeedOption = .speed
    
    @State private var showTopSpeed = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var previewUIView = UIView()
    @State private var shareImage: UIImage?
    @State private var showImageShareSheet = false
    @State private var showingSaveAlert = false
    let imageSaver = ImageSaver()
    @State private var scale: Double = 1.0
    @State private var showLocation = true
    
    var body: some View {
        ScrollView {
            SharePreviewWrapper(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showingSpeedInsteadPace: speedSelection == .speed ? true : false, showTopSpeed: showTopSpeed, showAverageSpeed: showAverageSpeed, scale: scale, locationName: statisticsData.locationString, showLocation: showLocation) { view in
                self.previewUIView = view
            }
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
            
            if useMap {
                Label("You can adjust the map window", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            
            Group {
                //                    Toggle("Use Map", isOn: $useMap)
                Stepper(value: $scale, in: 0.5...1.0, step: 0.1) {
                    HStack {
                        Text("Overlay Scale")
                        Spacer()
                        Text("\(scale, specifier: "%.1f")")
                            .monospacedDigit()
                    }
                }
                Toggle("Show Location", isOn: $showLocation)
                
                Picker("∅-Speed Format", selection: $speedSelection) {
                    ForEach(SpeedOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(!showAverageSpeed)
                
                Toggle("Show \(speedSelection.rawValue)", isOn: $showAverageSpeed)
                
                Toggle("Show Top Speed", isOn: $showTopSpeed)
                
                if !useMap {
                    HStack {
                        Button("Choose Photo") {
                            showImagePicker = true
                        }
                        Spacer()
                        Button("Take Photo") {
                            showCamera = true
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            HStack {
                Button {
                    shareImage = captureImage()
                    showImageShareSheet = true
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
            
        }
        
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showImageShareSheet, content: {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
            }
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
    ShareStatisticsView(downwindManager: DownwindManager(), statisticsData: RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: []))
}
