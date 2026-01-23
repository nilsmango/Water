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
            Map {
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
        let runsToLoad = runsForYear
        let totalRuns = runsToLoad.count
        var loadedCount = 0
        
        Task {
            for (index, run) in runsToLoad.enumerated() {
                await MainActor.run {
                    loadingProgress = "Loading route \(index + 1)/\(totalRuns)..."
                }
                
                await withCheckedContinuation { continuation in
                    downwindManager.loadRouteAndHeartFromHealth(statistic: run, withHeartRates: false) { _ in
                        loadedCount += 1
                        continuation.resume()
                    }
                }
                
                await MainActor.run {
                    loadedRuns.append(run)
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
