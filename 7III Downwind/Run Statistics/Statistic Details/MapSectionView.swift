//
//  MapSectionView.swift
//  7III Tracker
//
//  Created by Simon Lang on 18.06.2024.
//

import SwiftUI
import MapKit

struct MapSectionView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showRounds: Bool
    @Binding var showMapSheet: Bool
    @Binding var showAngleMap: Bool
    
    let rounds: [(String, String, String)]
    let flights: [(String, String, String, String)]
    let flightSummary: FlightSummary?
    let mapStyle: StatisticsMapStyle
    var windRouteAnalysis: WindRouteAnalysis? = nil
    @Binding var statisticsData: RunStatistic
    var onReverseWindDirections: (() -> Void)? = nil
    var onSetWindBearing: ((Double?) -> Void)? = nil
    @State private var showsWindBearingAlert = false
    @State private var windBearingText = ""
    
    var body: some View {
        let showsFlights = statisticsData.workoutType?.returnWaves == true
        let showsSegmentSection = showsFlights ? !flights.isEmpty : statisticsData.runDistance > 1999

        if showsSegmentSection {
            Section {
                if showsFlights {
                    StatisticsFlights(downwindManager: downwindManager, flights: flights, summary: flightSummary, overViewLayout: true)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showRounds = true
                        }
                } else {
                    StatisticsRounds(downwindManager: downwindManager, rounds: rounds, overViewLayout: true)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showRounds = true
                        }
                }
            } header: {
                HStack {
                    Text(showsFlights ? "Flights" : "Rounds")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Show all") {
                        showRounds = true
                    }
                    .textCase(nil)
                    .font(.body)
                }
                .padding(.bottom, 9)
            }
            .id(showsFlights ? "flights" : "rounds")
        }
        
        
        Section {
            Button {
                showMapSheet = true
            } label: {
                StatisticsRouteMapView(downwindManager: downwindManager, statisticsData: $statisticsData, mapStyle: mapStyle, windRouteAnalysis: windRouteAnalysis, lineWidth: thumbnailLineWidth, showsWindLegend: false)
                    .frame(height: 300)
                    .cornerRadius(8.0)
                    .disabled(true)
            }
            .id("map")
            
        } header: {
            HStack {
                Text("Map")
                    .textCase(nil)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Show more") {
                    showMapSheet = true
                }
                .textCase(nil)
                .font(.body)
            }
            .padding(.bottom, 9)
        } footer: {
            if statisticsData.workoutType?.isUpDownwindSport == true ||
                (statisticsData.workoutType?.angleSport == true && statisticsData.angles?.count ?? 0 < 1) {
                VStack {
                    if statisticsData.workoutType?.isUpDownwindSport == true,
                       onSetWindBearing != nil {
                        Button {
                            windBearingText = statisticsData.windFromBearing.map {
                                String(format: "%.0f", $0)
                            } ?? ""
                            showsWindBearingAlert = true
                        } label: {
                            Label(
                                statisticsData.windFromBearing.map {
                                    String(format: "Wind From %.0f°", $0)
                                } ?? "Set Wind Direction",
                                systemImage: "wind"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                    if statisticsData.workoutType?.isUpDownwindSport == true,
                       windRouteAnalysis != nil,
                       let onReverseWindDirections {
                        Button(action: onReverseWindDirections) {
                            Label(
                                statisticsData.windDirectionsReversed == true
                                    ? "Restore Automatic Wind Directions"
                                    : "Reverse Wind Directions",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                    if statisticsData.workoutType?.angleSport == true && statisticsData.angles?.count ?? 0 < 1 {
                        Button {
                            showAngleMap = true
                        } label: {
                            Label("Measure Angles", systemImage: "angle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .id("measureAngles")
                .alert("Wind From", isPresented: $showsWindBearingAlert) {
                    TextField("Degrees (0–359)", text: $windBearingText)
                    Button("Save") {
                        if isValidWindBearing,
                           let bearing = Double(windBearingText.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            onSetWindBearing?(bearing)
                        }
                    }
                    .disabled(!isValidWindBearing)
                    if statisticsData.windFromBearing != nil {
                        Button("Remove", role: .destructive) {
                            onSetWindBearing?(nil)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enter the compass direction the wind came from.")
                }
            }
        }
    }

    private var isValidWindBearing: Bool {
        guard let value = Double(windBearingText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return value.isFinite && (0..<360).contains(value)
    }
    
    private var thumbnailLineWidth: Double? {
        mapStyle == .gradient ? 1.5 : nil
    }
}

struct StatisticsRouteMapView: View {
    @ObservedObject var downwindManager: DownwindManager
    @Binding var statisticsData: RunStatistic
    
    let mapStyle: StatisticsMapStyle
    var windRouteAnalysis: WindRouteAnalysis? = nil
    var lineWidth: Double?
    var showsWindLegend = true
    
    var body: some View {
        switch mapStyle {
        case .neonYellow:
            StatisticsMap(
                downwindManager: downwindManager,
                statisticsData: $statisticsData,
                mapStyle: .neonYellow,
                lineWidthOverride: lineWidth ?? 2.0
            )
        case .gradient:
            SpeedGradientStatisticsMap(statisticsData: $statisticsData, lineWidth: lineWidth ?? 2.0)
        case .downwindGradient:
            StatisticsMap(
                downwindManager: downwindManager,
                statisticsData: $statisticsData,
                mapStyle: .downwindGradient,
                lineWidthOverride: lineWidth
            )
        case .windDirections:
            WindRouteStatisticsMap(
                statisticsData: $statisticsData,
                analysis: windRouteAnalysis,
                lineWidth: lineWidth ?? 2.0,
                showsLegend: showsWindLegend
            )
        }
    }
}

private struct WindRouteStatisticsMap: View {
    @Binding var statisticsData: RunStatistic
    let analysis: WindRouteAnalysis?
    let lineWidth: Double
    let showsLegend: Bool

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $position) {
                if let analysis {
                    ForEach(analysis.mapSegments) { segment in
                        MapPolyline(coordinates: segment.coordinates.map(\.mapCoordinate))
                            .stroke(
                                segment.direction.color,
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                    }

                    ForEach(analysis.angleMarkers) { marker in
                        MapPolyline(coordinates: [
                            marker.incomingPoint.mapCoordinate,
                            marker.incomingTurnPoint.mapCoordinate
                        ])
                        .stroke(
                            Color.purple,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )

                        MapPolyline(coordinates: [
                            marker.outgoingTurnPoint.mapCoordinate,
                            marker.outgoingPoint.mapCoordinate
                        ])
                        .stroke(
                            Color.purple,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )

                        Annotation("", coordinate: marker.vertex.mapCoordinate) {
                            Text(String(format: "%.0f°", marker.angle))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple, in: Capsule())
                        }
                    }
                } else if statisticsData.locationData.count > 1 {
                    MapPolyline(coordinates: statisticsData.locationData.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(.neonYellow, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }

                if let start = statisticsData.locationData.first {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude)) {
                        Circle()
                            .fill(.green)
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }

                if let finish = statisticsData.locationData.last {
                    Annotation("Finish", coordinate: CLLocationCoordinate2D(latitude: finish.latitude, longitude: finish.longitude)) {
                        Circle()
                            .fill(.red)
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .mapStyle(.standard)

            if analysis != nil, showsLegend {
                WindRouteLegend()
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
            } else if analysis == nil, showsLegend {
                WindRouteUnavailableMessage()
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: analysis) { _, _ in
            position = .automatic
        }
    }
}

struct WindRouteLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            WindRouteLegendRow(color: .neonYellow, text: "Upwind")
            WindRouteLegendRow(color: .green, text: "Downwind")
            WindRouteLegendRow(color: .gray, text: "Idle")
        }
        .font(.caption2)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(WindMapOverlayBackground())
    }
}

struct WindRouteUnavailableMessage: View {
    var body: some View {
        Label("Couldn’t find wind direction data", systemImage: "wind")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .modifier(WindMapOverlayBackground())
    }
}

private struct WindMapOverlayBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct WindRouteLegendRow: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 4)
            Text(text)
        }
    }
}

private extension WindRouteCoordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension WindRouteDirection {
    var color: Color {
        switch self {
        case .upwind: .neonYellow
        case .downwind: .green
        case .idle: .gray
        }
    }
}

#Preview {
    List {
        MapSectionView(downwindManager: DownwindManager(), showRounds: .constant(false), showMapSheet: .constant(false), showAngleMap: .constant(false), rounds: [], flights: [], flightSummary: nil, mapStyle: .gradient, statisticsData: .constant(RunStatistic(id: UUID(), runName: "Testrun", crewStatistics: [], runTime: 81.1, runDistance: 2000, topSpeed: 26, locationData: decodeLocationSampleData() ?? Constants.locationSampleData, tags: [])))
    }
}
