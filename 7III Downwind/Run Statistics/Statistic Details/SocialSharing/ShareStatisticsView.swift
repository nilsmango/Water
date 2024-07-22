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
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var previewUIView = UIView()
    @State private var shareImage: UIImage?
    @State private var showImageShareSheet = false
    
    var body: some View {
            ScrollView {
                SharePreviewWrapper(downwindManager: downwindManager, statisticsData: statisticsData, useMap: useMap, showAverageSpeed: showAverageSpeed) { view in
                                self.previewUIView = view
                            }
                .frame(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.width - 32)
                .shadow(radius: 5)
                .padding(.vertical, 16)
                
                if useMap {
                    Label("You can modify the map window", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                    
                
                Group {
                    Toggle("Use Map", isOn: $useMap)
                    // TODO: make this a picker
                    Toggle("Show Average Speed (or Pace)", isOn: $showAverageSpeed)
                    
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
                .padding(.horizontal, 16)
                
                Button("Capture Image") {
                    shareImage = captureImage()
                    showImageShareSheet = true
                }
//               
//                if let image = shareImage {
//                    ShareLink(item: captureImage(), preview: SharePreview("Share", image: captureImage()))
//                    {
//                        Label("Share", systemImage: "square.and.arrow.up")
//                    }
//                        .buttonStyle(.borderedProminent)
//                        .padding()
//                }
                
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
        }
    
//    private func generateShareImage() -> UIImage {
//        let content = previewView
//        return content.snapshot()
//    }
    
    private func captureImage() -> UIImage {
        
                let renderer = UIGraphicsImageRenderer(size: previewUIView.bounds.size)
        let capturedImage = renderer.image { _ in
            previewUIView.drawHierarchy(in: previewUIView.bounds, afterScreenUpdates: true)
                }
        return capturedImage
//            capturedImage = previewUIView.snapshot()
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
