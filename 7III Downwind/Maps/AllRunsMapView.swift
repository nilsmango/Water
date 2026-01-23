//
//  AllRunsMapView.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.01.2026.
//

import SwiftUI
import MapKit

struct AllRunsMapView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @AppStorage("selectedYear") private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isLoading = false
    @State private var loadingProgress = ""
    @State private var loadedRuns: [RunStatistic] = []
    @State private var hasLoadedCoordinates = false
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
    )
    
    private var availableYears: [Int] {
        let years = Set(downwindManager.runStatistics.compactMap { statistic -> Int? in
            guard let date = statistic.startDate ?? statistic.locationData.first?.timestamp else { return nil }
            return Calendar.current.component(.year, from: date)
        })
        return years.sorted(by: >)
    }
    
    private var runsForYear: [RunStatistic] {
        downwindManager.runStatistics.filter { statistic in
            guard let date = statistic.startDate ?? statistic.locationData.first?.timestamp else { return false }
            return Calendar.current.component(.year, from: date) == selectedYear
        }
    }
    
    var body: some View {
        ZStack {
            Map(position: $mapPosition) {
                ForEach(loadedRuns) { run in
                    if !run.locationData.isEmpty {
                        
                            MapPolyline(coordinates: makeSmoothedCoordinates(from: run.locationData, removeGpsMistakes: true))
                                .stroke(
                                    .neonYellow,
                                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                                )
                        
                        
                        if let startData = run.locationData.first {
                            let startCoordinate = CLLocationCoordinate2D(latitude: startData.latitude, longitude: startData.longitude)
                            Annotation("", coordinate: startCoordinate) {
                                Circle()
                                    .fill(Color.green)
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 10.0)
                            }
                        }
                        
                        if let endData = run.locationData.last {
                            let endCoordinate = CLLocationCoordinate2D(latitude: endData.latitude, longitude: endData.longitude)
                            Annotation("", coordinate: endCoordinate) {
                                Circle()
                                    .fill(Color.red)
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 10.0)
                            }
                        }
                    }
                }
            }
            
            VStack {
                if !availableYears.isEmpty {
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(loadingProgress)
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
        .onChange(of: selectedYear) { _, _ in
            hasLoadedCoordinates = false
            loadedRuns = []
            loadCoordinates()
        }
        .onAppear {
            loadCoordinates()
        }
    }
    
    private func loadCoordinates() {
        guard !hasLoadedCoordinates else { return }
        
        isLoading = true
        let runsToLoad = runsForYear.sorted { run1, run2 in
            let date1 = run1.startDate ?? run1.locationData.first?.timestamp ?? Date.distantFuture
            let date2 = run2.startDate ?? run2.locationData.first?.timestamp ?? Date.distantFuture
            return date1 < date2
        }
        let totalRuns = runsToLoad.count
        var loadedCount = 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        Task {
            for (index, run) in runsToLoad.enumerated() {
                let runDate = run.startDate ?? run.locationData.first?.timestamp
                let dateString = runDate.map { dateFormatter.string(from: $0) } ?? "Unknown date"
                
                await MainActor.run {
                    loadingProgress = "Loading route \(index + 1)/\(totalRuns): \(dateString)"
                }
                
                await withCheckedContinuation { continuation in
                    downwindManager.loadRouteAndHeartFromHealth(statistic: run, withHeartRates: false) { _ in
                        loadedCount += 1
                        continuation.resume()
                    }
                }
                
                await MainActor.run {
                    if let updatedRun = downwindManager.runStatistics.first(where: { $0.id == run.id }) {
                        loadedRuns.append(updatedRun)
                        
                        if !updatedRun.locationData.isEmpty {
                            let coordinates = makeSmoothedCoordinates(from: updatedRun.locationData, removeGpsMistakes: true)
                            if !coordinates.isEmpty {
                                let minLat = coordinates.map { $0.latitude }.min() ?? 0
                                let maxLat = coordinates.map { $0.latitude }.max() ?? 0
                                let minLon = coordinates.map { $0.longitude }.min() ?? 0
                                let maxLon = coordinates.map { $0.longitude }.max() ?? 0
                                
                                let center = CLLocationCoordinate2D(
                                    latitude: (minLat + maxLat) / 2,
                                    longitude: (minLon + maxLon) / 2
                                )
                                
                                let span = MKCoordinateSpan(
                                    latitudeDelta: (maxLat - minLat) * 2.0,
                                    longitudeDelta: (maxLon - minLon) * 2.0
                                )
                                
                                mapPosition = .region(MKCoordinateRegion(center: center, span: span))
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
                loadingProgress = ""
                hasLoadedCoordinates = true
            }
        }
    }
}

#Preview {
    AllRunsMapView(downwindManager: DownwindManager())
}
