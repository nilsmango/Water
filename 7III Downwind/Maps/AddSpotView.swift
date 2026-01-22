//
//  AddSpotView.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import SwiftUI
import CoreLocation

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var kind: Spot.Kind = .pumpFoilDock
    @State private var country = ""
    @State private var usState: String? = nil
    @State private var locations: [[String: Double]] = []
    @State private var distance = ""
    @State private var infos: [SpotInfo] = []
    @State private var videos: [Video] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    var initialLocations: [[String: Double]]
    
    init(initialLocations: [[String: Double]] = []) {
        self.initialLocations = initialLocations
        _locations = State(initialValue: initialLocations)
        let isRoute = initialLocations.count > 1
        _kind = State(initialValue: isRoute ? .downwindRun : .pumpFoilDock)
    }
    
    var isRoute: Bool {
        locations.count > 1
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Spot Name", text: $name)
                    
                    SpotKindPicker(
                        kind: $kind,
                        availableKinds: isRoute ? [.downwindRun, .paddleTour] : Spot.Kind.allCases.filter { $0 != .downwindRun && $0 != .paddleTour }
                    )
                    
                    CountryPicker(country: $country, state: $usState)
                    
                    if isRoute {
                        HStack {
                            Text("Distance (km)")
                            TextField("0.0", text: $distance)
                                .keyboardType(.decimalPad)
                        }
                    }
                    
                } header: {
                    Text("Basic Information")
                }
                
                Section {
                    ForEach(infos.indices, id: \.self) { index in
                        InfoSectionView(info: $infos[index]) {
                            withAnimation {
                                infos = infos.filter { $0.id != infos[index].id }
                            }
                        }
                    }
                    
                    Button(action: addInfo) {
                        Label("Add Info", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Information")
                }
                
                Section {
                    ForEach(videos.indices, id: \.self) { index in
                        VideoSectionView(video: $videos[index]) {
                            withAnimation {
                                videos = videos.filter { $0.id != videos[index].id }
                            }
                        }
                    }
                    
                    Button(action: addVideo) {
                        Label("Add Video", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Videos")
                }
                
                .toolbar(content: {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: submit) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Submit")
                            }
                        }
                        .disabled(isSubmitting || name.isEmpty || country.isEmpty || locations.isEmpty)
                    }
                })
            }
            .navigationTitle("Add Spot")
            .navigationBarTitleDisplayMode(.inline)
            
            
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    showingSuccess = false
                    dismiss()
                }
            } message: {
                Text("Spot submitted successfully! It will appear as pending until reviewed.")
            }
            .onAppear {
                reverseGeocode()
            }
        }
    }
    
    private func addInfo() {
        infos.append(SpotInfo(
            id: UUID().uuidString,
            spotId: nil,
            tag: .description,
            text: "",
            date: ISO8601DateFormatter().string(from: Date()),
            userName: "",
            userUrl: nil,
            votes: nil
        ))
    }
    
    private func addVideo() {
        videos.append(Video(
            id: UUID().uuidString,
            url: "https://",
            date: ISO8601DateFormatter().string(from: Date()),
            kind: .other
        ))
    }
    
    private func submit() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                let distanceValue = isRoute ? Double(distance) : nil
                
                let request = SubmitSpotRequest(
                    name: name,
                    kind: kind.rawValue,
                    country: country,
                    usState: usState,
                    locations: locations,
                    distance: distanceValue,
                    infos: infos,
                    videos: videos
                )
                
                let response = try await SpotManager.shared.submitSpot(request)
                
                await MainActor.run {
                    if response.success {
                        showingSuccess = true
                    } else {
                        errorMessage = response.message ?? "Unknown error"
                    }
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
    
    private func reverseGeocode() {
        guard !locations.isEmpty else { return }
        
        let locationNames = NSMutableArray()
        let group = DispatchGroup()
        
        if let firstLoc = locations.first, let lat = firstLoc["lat"], let lng = firstLoc["lng"] {
            group.enter()
            GeocodingManager.shared.getNameOfLocation(location: LocationData(timestamp: Date(), latitude: lat, longitude: lng)) { name in
                if let name = name {
                    locationNames.add(name)
                }
                group.leave()
            }
        }
        
        if locations.count > 1, let lastLoc = locations.last, let lat = lastLoc["lat"], let lng = lastLoc["lng"] {
            group.enter()
            GeocodingManager.shared.getNameOfLocation(location: LocationData(timestamp: Date(), latitude: lat, longitude: lng)) { name in
                if let name = name {
                    locationNames.add(name)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if locationNames.count == 1, let firstName = locationNames.first as? String {
                name = firstName
            } else if locationNames.count >= 2 {
                let firstName = locationNames[0] as? String ?? ""
                let lastName = locationNames[locationNames.count - 1] as? String ?? ""
                name = "\(firstName) → \(lastName)"
            }
        }
    }
}
