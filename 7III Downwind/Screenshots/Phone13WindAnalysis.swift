#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone13WindAnalysis: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1616,
            titleLines: ["Auto Angles", "Down/Up %"],
            phoneOffsetY: 230,
            phoneColorScheme: .dark
        ) {
            ScreenshotWindAnalysisView()
        }
    }
}

struct ScreenshotWindAnalysisView: View {
    @StateObject private var downwindManager = DownwindManager()
    @State private var statistic: RunStatistic
    @State private var mapStyle: StatisticsMapStyle = .windDirections
    private let analysis: WindRouteAnalysis

    init(
        fixtureName: String = "carqueiranne-wind-route",
        expectedCount: Int = 3_663,
        startTimestamp: TimeInterval = 1_789_576_744,
        windFromBearing: Double? = nil,
        workoutType: WorkoutType = .dWParawing
    ) {
        let locations = Self.loadLocations(
            fixtureName: fixtureName,
            expectedCount: expectedCount,
            startTimestamp: startTimestamp
        )
        guard let analysis = analyzeWindRoute(from: locations, windFromBearing: windFromBearing) else {
            preconditionFailure("The Carqueiranne screenshot route must produce wind analysis")
        }

        var statistic = RunStatistic(
            id: UUID(uuidString: "CACE1616-2026-4916-8000-000000000000")!,
            runName: "DW Parawing",
            crewStatistics: [],
            runTime: locations.last!.timestamp.timeIntervalSince(locations.first!.timestamp) / 60,
            runDistance: 0,
            topSpeed: 0,
            locationData: locations
        )
        statistic.workoutType = workoutType
        statistic.locationString = "Carqueiranne"
        statistic.startDate = locations.first?.timestamp
        statistic.endDate = locations.last?.timestamp
        statistic.windFromBearing = windFromBearing

        _statistic = State(initialValue: statistic)
        self.analysis = analysis
    }

    var body: some View {
        NavigationStack {
            StatisticsFullMapView(
                downwindManager: downwindManager,
                statisticsData: $statistic,
                mapStyle: $mapStyle,
                windRouteAnalysis: analysis
            )
            .navigationTitle(statistic.locationString ?? "Carqueiranne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {} label: {
                        XMarkLabel()
                    }
                }
            }
        }
    }

    /// A compact coordinate/time/speed extract of the supplied GPX.
    private static func loadLocations(
        fixtureName: String,
        expectedCount: Int,
        startTimestamp: TimeInterval
    ) -> [LocationData] {
        guard let url = Bundle.main.url(forResource: fixtureName, withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Missing Carqueiranne screenshot route fixture")
        }

        let start = Date(timeIntervalSince1970: startTimestamp)
        let locations = text.split(whereSeparator: \.isNewline).compactMap { line -> LocationData? in
            guard !line.hasPrefix("#") else { return nil }
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let offset = Double(fields[0]),
                  let latitude = Double(fields[1]),
                  let longitude = Double(fields[2]) else { return nil }
            return LocationData(
                timestamp: start.addingTimeInterval(offset),
                latitude: latitude,
                longitude: longitude,
                speed: Double(fields[3])
            )
        }
        precondition(locations.count == expectedCount, "The Carqueiranne screenshot route is incomplete")
        return locations
    }
}

#Preview {
    Phone13WindAnalysis.preview()
}
#endif
