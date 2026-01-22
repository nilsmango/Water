//
//  SpotsView.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2026.
//

import SwiftUI
import MapKit

struct SpotsView: View {
    @StateObject private var spotManager = SpotManager.shared
    
    @State private var selectedSpot: Spot?
    @State private var showFilters = false
    @State private var selectedKinds: Set<Spot.Kind> = Set(Spot.Kind.allCases)
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.8, longitude: 8.2),
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
    )
    
    private var lineWidth = 2.0
    
    var filteredSpots: [Spot] {
        spotManager.filteredSpots(kinds: selectedKinds)
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
                                    .neonYellow,
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )

                            if let startCoord = coordinates.first {
                                Annotation("Start", coordinate: startCoord) {
                                    Circle()
                                        .fill(Color.green)
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: 15.0)
                                }
                            }

                            if let endCoord = coordinates.last {
                                Annotation("Finish", coordinate: endCoord) {
                                    Circle()
                                        .fill(Color.red)
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: 15.0)
                                }
                            }
                            }
                        } else if let location = spot.primaryLocation {
                            Annotation(spot.name, coordinate: location.coordinate) {
                                Circle()
                                    .fill(spot.pending == true ? Color.gray : Color.accentColor)
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 15.0)
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

            VStack(spacing: 8) {
                Button {
                    Task {
                        await spotManager.refreshSpots()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background {
                            Circle()
                                .fill(Color.accentColor)
                        }
                }
                .padding()
                .padding(.trailing, showFilters ? 50 : 0)

                Button {
                    showFilters.toggle()
                } label: {
                    Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background {
                            Circle()
                                .fill(Color.accentColor)
                        }
                }
                .padding()

                if spotManager.isLoading {
                    ProgressView()
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 16.0)
                                .fill(.white.opacity(0.6))
                        }
                        .padding()
                }
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .sheet(isPresented: $showFilters) {
            FiltersView(
                selectedKinds: $selectedKinds,
                allKinds: Spot.Kind.allCases
            )
        }
        .onAppear {
            Task {
                await spotManager.loadSpots()
            }
        }
        .refreshable {
            await spotManager.refreshSpots()
        }
    }
    
    private func handleTap(at coordinate: CLLocationCoordinate2D) {
        let threshold = 0.001
        
        if let tappedSpot = filteredSpots.first(where: { spot in
            if let location = spot.primaryLocation {
                let latDiff = abs(location.lat - coordinate.latitude)
                let lngDiff = abs(location.lng - coordinate.longitude)
                return latDiff < threshold && lngDiff < threshold
            }
            return false
        }) {
            selectedSpot = tappedSpot
        }
    }
}

struct FiltersView: View {
    @Binding var selectedKinds: Set<Spot.Kind>
    let allKinds: [Spot.Kind]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
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
