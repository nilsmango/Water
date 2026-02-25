//
//  SpotsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2026.
//

import SwiftUI
import MapKit
import Combine

struct SpotsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotManager = SpotManager.shared
    
    @State private var selectedSpot: Spot?
    @State private var showFilters = false
    @State private var showAddSpot = false
    @State private var selectedKinds: Set<Spot.Kind> = Set(Spot.Kind.allCases)
    @State private var showPendingOnly = false
    @State private var hidePending = false
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.8, longitude: 8.2),
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
    )
    
    @State private var isAddingSpot = false
    @State private var newSpotLocations: [[String: Double]] = []
    @State private var cancellables = Set<AnyCancellable>()
    
    private var lineWidth = 2.0
    private let refreshTimerInterval: TimeInterval = 10 * 60
    
    var filteredSpots: [Spot] {
        let spotsByKind = spotManager.filteredSpots(kinds: selectedKinds)
        
        if showPendingOnly {
            return spotsByKind.filter { $0.pending == true }
        } else if hidePending {
            return spotsByKind.filter { $0.pending == nil || $0.pending == false }
        } else {
            return spotsByKind
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapReader { proxy in
                Map(position: $mapPosition) {
    
                    ForEach(filteredSpots) { spot in
                        if spot.isDownwindRun {
                            let coordinates = spot.locations.compactMap { $0.coordinate }
                            if coordinates.count >= 2 {
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    spot.kind != .downwindRun ? .green : .neonYellow,
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                                

                            if let startCoord = coordinates.first {
                                Annotation("", coordinate: startCoord) {
                                    Circle()
                                        .fill(Color.green)
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: 15.0)
                                        .onTapGesture {
                                            if !isAddingSpot {
                                                selectedSpot = spot
                                            }
                                        }
                                }
                                
                            }

                            if let endCoord = coordinates.last {
                                Annotation("", coordinate: endCoord) {
                                    Circle()
                                        .fill(Color.red)
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: 15.0)
                                        .onTapGesture {
                                            if !isAddingSpot {
                                                selectedSpot = spot
                                            }
                                        }
                                }
                                
                            }
                            }
                        } else if let location = spot.primaryLocation {
                            Annotation(spot.name, coordinate: location.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(spot.pending == true ? Color.gray : Color.accentColor)
                                        .stroke(.white, lineWidth: 1)
                                        .frame(width: 18.0)
                                    
                                    Image(systemName: spot.kind.iconName)
                                        .foregroundStyle(.black)
                                        .font(.system(size: 10))
                                }
                                .onTapGesture {
                                    if !isAddingSpot {
                                        selectedSpot = spot
                                    }
                                }

                            }
                        }
                    }
                    
                    if isAddingSpot {
                        let tempCoordinates = newSpotLocations.compactMap { loc -> CLLocationCoordinate2D? in
                            guard let lat = loc["lat"], let lng = loc["lng"] else { return nil }
                            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        }
                        
                        if tempCoordinates.count >= 2 {
                            MapPolyline(coordinates: tempCoordinates)
                                .stroke(
                                    .neonYellow,
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                        }
                        
                        ForEach(Array(tempCoordinates.enumerated()), id: \.offset) { index, coord in
                            if index == 0 || index == tempCoordinates.count - 1 {
                                Annotation("", coordinate: coord) {
                                    Circle()
                                        .fill(Color.gray)
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: 12.0)
//                                        .onTapGesture {
//                                            if index == tempCoordinates.count - 1 {
//                                                tempCoordinates.remove(at: index)
//                                            }
//                                        }
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        handleTap(at: coordinate)
                    }
                }
            }
    
            VStack(spacing: 16) {
                Spacer()
                if !isAddingSpot {
                    
                    Button {
                        isAddingSpot = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background {
                                Circle()
                                    .fill(Color.accentColor)
                            }
                    }
                    .padding(.horizontal)
                    
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background {
                                Circle()
                                    .fill(Color.accentColor)
                            }
                    }
                    .padding(.horizontal)
                }
            }
    
            if isAddingSpot {
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Text("Mark the Spot")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Label("For downwind runs or paddle tours, mark the route (more points is better).", systemImage: "info.circle")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Button("Cancel") {
                                isAddingSpot = false
                                newSpotLocations.removeAll()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Done") {
                                isAddingSpot = false
                                showAddSpot = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    newSpotLocations = []
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newSpotLocations.isEmpty)
                        }
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 10)
                    }
                    .padding()
                }
                
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .sheet(isPresented: $showAddSpot) {
            AddSpotView(initialLocations: newSpotLocations) {
                Task {
                    showAddSpot = false
                    try? await Task.sleep(nanoseconds: UInt64(2.0 * 1_000_000_000))
                    await spotManager.refreshSpots()
                }
            }
            .presentationDetents([.large, .medium, .fraction(0.3)])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showFilters) {
            FiltersView(
                selectedKinds: $selectedKinds,
                showPendingOnly: $showPendingOnly,
                hidePending: $hidePending,
                allKinds: Spot.Kind.allCases
            )
        }
        .onAppear {
            Task {
                await spotManager.loadSpots()
            }
            Timer.publish(every: refreshTimerInterval, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    Task {
                        await spotManager.refreshSpots()
                    }
                }
                .store(in: &cancellables)
        }
        .refreshable {
            await spotManager.refreshSpots()
        }
    }
    
    private func handleTap(at coordinate: CLLocationCoordinate2D) {
        if isAddingSpot {
            newSpotLocations.append(["lat": coordinate.latitude, "lng": coordinate.longitude])
            return
        }
        if selectedSpot == nil {
            let threshold = 0.01
            var closestSpot: Spot?
            var minDistance = Double.infinity
            
            for spot in filteredSpots {
                if let location = spot.primaryLocation {
                    let latDiff = abs(location.lat - coordinate.latitude)
                    let lngDiff = abs(location.lng - coordinate.longitude)
                    let distance = sqrt(latDiff * latDiff + lngDiff * lngDiff)
                    if distance < threshold && distance < minDistance {
                        minDistance = distance
                        closestSpot = spot
                    }
                }
                
                let coordinates = spot.locations.compactMap { $0.coordinate }
                for coord in coordinates {
                    let latDiff = abs(coord.latitude - coordinate.latitude)
                    let lngDiff = abs(coord.longitude - coordinate.longitude)
                    let distance = sqrt(latDiff * latDiff + lngDiff * lngDiff)
                    if distance < threshold && distance < minDistance {
                        minDistance = distance
                        closestSpot = spot
                    }
                }
                
                if coordinates.count >= 2 {
                    for i in 0..<coordinates.count - 1 {
                        let distance = distanceToLineSegment(point: coordinate, start: coordinates[i], end: coordinates[i + 1])
                        if distance < threshold && distance < minDistance {
                            minDistance = distance
                            closestSpot = spot
                        }
                    }
                }
            }
            
            if let tappedSpot = closestSpot {
                selectedSpot = tappedSpot
            }
        }
        
    }
    
    private func distanceToLineSegment(point: CLLocationCoordinate2D, start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> Double {
        let A = point.latitude - start.latitude
        let B = point.longitude - start.longitude
        let C = end.latitude - start.latitude
        let D = end.longitude - start.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        var param = -1.0
        if lenSq != 0 {
            param = dot / lenSq
        }
        
        var closestLatitude: Double
        var closestLongitude: Double
        
        if param < 0 {
            closestLatitude = start.latitude
            closestLongitude = start.longitude
        } else if param > 1 {
            closestLatitude = end.latitude
            closestLongitude = end.longitude
        } else {
            closestLatitude = start.latitude + param * C
            closestLongitude = start.longitude + param * D
        }
        
        let latDiff = point.latitude - closestLatitude
        let lonDiff = point.longitude - closestLongitude
        
        return sqrt(latDiff * latDiff + lonDiff * lonDiff)
    }
}

struct FiltersView: View {
    @Binding var selectedKinds: Set<Spot.Kind>
    @Binding var showPendingOnly: Bool
    @Binding var hidePending: Bool
    let allKinds: [Spot.Kind]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if showPendingOnly {
                            showPendingOnly = false
                        } else {
                            showPendingOnly = true
                            hidePending = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .frame(width: 30)
                            
                            Text("Pending spots only")
                            
                            Spacer()
                            
                            if showPendingOnly {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                
                Button {
                    if hidePending {
                        hidePending = false
                    } else {
                        hidePending = true
                        showPendingOnly = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                                .frame(width: 30)
                            
                            Text("Hide pending spots")
                            
                            Spacer()
                            
                            if hidePending {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                
                Section {
                    ForEach(allKinds, id: \.self) { kind in
                        Button {
                            if selectedKinds.contains(kind) {
                                selectedKinds.remove(kind)
                            } else {
                                selectedKinds.insert(kind)
                            }
                        } label: {
                            HStack {
                                Image(systemName: kind.iconName)
                                    .frame(width: 30)
                                    
                                Text(kind.label)
                                    
                                Spacer()
                                    
                                if selectedKinds.contains(kind) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Spots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SpotsView()
}
