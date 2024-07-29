//
//  VideoPicker.swift
//  7III Tracker
//
//  Created by Simon Lang on 29.07.2024.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideo: URL?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let error = error {
                        print("Error loading video: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let url = url else {
                        print("URL is nil")
                        return
                    }
                    
                    // Create a copy of the file in the app's temporary directory
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    do {
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try FileManager.default.removeItem(at: tempURL)
                        }
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        
                        DispatchQueue.main.async {
                            self.parent.selectedVideo = tempURL
                        }
                    } catch {
                        print("Error copying file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
