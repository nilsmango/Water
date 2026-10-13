import CoreLocation
import Foundation
import Testing
@testable import _III_Water_Screenshots

struct StatisticsRoundsTests {
    @Test func ignoresKilometerScaleGPSJumpsFromLaCiotatRoute() {
        let rounds = calculateStatisticsRounds(
            from: Self.routeWithLaCiotatGPSJumps(),
            workoutType: .downwindSUPFoil
        )

        #expect(rounds.count == 3)
        #expect(rounds.map(\.0).prefix(2).elementsEqual(["1", "2"]))
        let finalDistance = Double(rounds[2].0) ?? 0
        #expect((2.8...3.1).contains(finalDistance))
        #expect(rounds.allSatisfy { !$0.1.hasPrefix("-") })
    }

    @Test func removesTheLaCiotatJumpClusterFromTheSavedRouteAndMetrics() {
        let rawLocations = Self.routeWithLaCiotatGPSJumps()
        let cleanedLocations = cleanGPSRoute(from: rawLocations, workoutType: .downwindSUPFoil)
        let lastExpectedTimestamp = rawLocations.last?.timestamp
        let metrics = calculateGPSRouteMetrics(from: cleanedLocations, workoutType: .downwindSUPFoil)
        let shortWindowTopSpeeds = calculateTopSpeeds(
            from: rawLocations,
            workoutType: .downwindSUPFoil
        )

        #expect(cleanedLocations.count == rawLocations.count - 3)
        #expect(cleanedLocations.last?.timestamp == lastExpectedTimestamp)
        #expect(metrics.totalDistance > 2_900)
        #expect(metrics.totalDistance < 3_000)
        #expect(metrics.topSpeedKmh < 78)
        #expect((shortWindowTopSpeeds.topSpeed1Sec ?? 0) < 78)
        #expect((shortWindowTopSpeeds.topSpeed10Sec ?? 0) < 78)
        #expect(!cleanedLocations.contains { $0.latitude > 43.17 })
    }

    @Test func duplicateTimestampsDoNotInflateRouteDistanceOrTopSpeed() {
        let latitude = 43.12718
        let longitude = 5.71225
        let start = Date(timeIntervalSince1970: 0)
        let metersPerLongitudeDegree = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude + 1))
        let locations = [
            LocationData(timestamp: start, latitude: latitude, longitude: longitude, speed: 8),
            LocationData(timestamp: start.addingTimeInterval(1), latitude: latitude, longitude: longitude + 8 / metersPerLongitudeDegree, speed: 8),
            // This second fix is serialized in the same GPX second. Dropping it
            // must not make the next one-second coordinate delta count twice.
            LocationData(timestamp: start.addingTimeInterval(1), latitude: latitude, longitude: longitude + 16 / metersPerLongitudeDegree, speed: 8),
            LocationData(timestamp: start.addingTimeInterval(2), latitude: latitude, longitude: longitude + 24 / metersPerLongitudeDegree, speed: 8)
        ]

        let cleanedLocations = cleanGPSRoute(from: locations, workoutType: .downwindSUPFoil)
        let metrics = calculateGPSRouteMetrics(from: cleanedLocations, workoutType: .downwindSUPFoil)
        let topSpeeds = calculateTopSpeeds(from: locations, workoutType: .downwindSUPFoil)

        #expect(cleanedLocations.count == 3)
        #expect(abs(metrics.totalDistance - 16) < 1)
        #expect(metrics.topSpeedKmh < 30)
        #expect((topSpeeds.topSpeed1Sec ?? 100) < 30)
    }

    @Test func gpsFilterReacquiresAfterAStableSeriesOfBadFixes() {
        let start = Date(timeIntervalSince1970: 0)
        let latitude = 43.0
        let longitude = 5.6
        var filter = GPSRouteFilter(workoutType: .downwindSUPFoil)
        let locations = [
            LocationData(timestamp: start, latitude: latitude, longitude: longitude)
        ] + (1...6).map { index in
            LocationData(
                timestamp: start.addingTimeInterval(Double(index)),
                latitude: index == 1 ? 43.02 : 43.02 + Double(index - 1) * 0.000001,
                longitude: longitude
            )
        }

        let filteredLocations = filter.filter(locations)
        let reloadedLocations = cleanGPSRoute(from: filteredLocations, workoutType: .downwindSUPFoil)
        let metrics = calculateGPSRouteMetrics(from: reloadedLocations, workoutType: .downwindSUPFoil)

        #expect(filteredLocations.count == 3)
        #expect(filteredLocations[1].isRouteSegmentStart == true)
        #expect(filteredLocations.last?.timestamp == start.addingTimeInterval(6))
        #expect(reloadedLocations == filteredLocations)
        #expect(metrics.totalDistance < 5)
    }

    @Test func longGPSGapStartsANewSegmentAndDistanceMatchesRounds() {
        let start = Date(timeIntervalSince1970: 0)
        let latitude = 43.0
        let longitude = 5.6
        let metersPerLongitudeDegree = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude + 1))
        let locations = [
            LocationData(timestamp: start, latitude: latitude, longitude: longitude),
            LocationData(timestamp: start.addingTimeInterval(10), latitude: latitude, longitude: longitude + 100 / metersPerLongitudeDegree),
            LocationData(timestamp: start.addingTimeInterval(1_360), latitude: latitude, longitude: longitude + 1_100 / metersPerLongitudeDegree),
            LocationData(timestamp: start.addingTimeInterval(1_370), latitude: latitude, longitude: longitude + 1_200 / metersPerLongitudeDegree)
        ]

        let cleanedLocations = cleanGPSRoute(from: locations, workoutType: .downwindSUPFoil)
        let metrics = calculateGPSRouteMetrics(from: cleanedLocations, workoutType: .downwindSUPFoil)
        let rounds = calculateStatisticsRounds(from: locations, workoutType: .downwindSUPFoil)
        let splitDistance = Double(rounds.last?.0 ?? "0") ?? 0

        #expect(cleanedLocations.count == locations.count)
        #expect(cleanedLocations[2].isRouteSegmentStart == true)
        #expect(abs(metrics.totalDistance - 200) < 2)
        #expect(abs(splitDistance - metrics.totalDistance / 1_000) < 0.01)
    }

    @Test func interpolatesEveryKilometerInsideASparsePlausibleSample() {
        let latitude = 43.0
        let longitude = 5.6
        let metersPerLongitudeDegree = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude + 1))
        let start = Date(timeIntervalSince1970: 0)
        let locations = [
            LocationData(timestamp: start, latitude: latitude, longitude: longitude),
            LocationData(
                timestamp: start.addingTimeInterval(100),
                latitude: latitude,
                longitude: longitude + 2_020 / metersPerLongitudeDegree
            ),
            LocationData(
                timestamp: start.addingTimeInterval(110),
                latitude: latitude,
                longitude: longitude + 2_070 / metersPerLongitudeDegree
            )
        ]

        let rounds = calculateStatisticsRounds(from: locations, workoutType: .windsurf)

        #expect(rounds.map(\.0) == ["1", "2", "2.1"])
        #expect(rounds[0].1 == "0:50")
        #expect(rounds[1].1 == "0:50")
        #expect(rounds.allSatisfy { !$0.1.hasPrefix("-") })
    }

    private static func routeWithLaCiotatGPSJumps() -> [LocationData] {
        let latitude = 43.15942116099635
        let endLongitude = 5.608531526497093
        let startTime = Date(timeIntervalSince1970: 0)
        let metersPerLongitudeDegree = 111_320 * cos(latitude * .pi / 180)
        let startLongitude = endLongitude - 2_500 / metersPerLongitudeDegree

        var locations = (0...500).map { index in
            let fraction = Double(index) / 500
            return LocationData(
                timestamp: startTime.addingTimeInterval(Double(index)),
                latitude: latitude,
                longitude: startLongitude + (endLongitude - startLongitude) * fraction
            )
        }

        // These points reproduce the 10 October GPX's jumps around samples 738–742.
        // The two impossible legs are about 2.2 km in 62 s and 2.7 km in 16 s.
        let anomaly: [(TimeInterval, Double, Double)] = [
            (62, 43.177778216391744, 5.618056954516789),
            (93, 43.17824815094118, 5.618824686099969),
            (183, 43.17820058011275, 5.619005778161962),
            (199, 43.15618302153165, 5.605212897061267),
            (200, 43.15618286, 5.60521383)
        ]
        locations += anomaly.map { seconds, latitude, longitude in
            LocationData(
                timestamp: startTime.addingTimeInterval(500 + seconds),
                latitude: latitude,
                longitude: longitude
            )
        }

        return locations
    }
}
