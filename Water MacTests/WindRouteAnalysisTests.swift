import Foundation
import Testing
@testable import Water_Mac

struct WindRouteAnalysisTests {
    @Test func separatesOpposingWindDirectionsAndIdleTime() {
        let analysis = analyzeWindRoute(from: Self.syntheticUpDownwindRoute())

        #expect(analysis != nil)
        #expect((analysis?.upwindDuration ?? 0) > (analysis?.downwindDuration ?? 0))
        #expect((analysis?.upwindDistance ?? 0) > (analysis?.downwindDistance ?? 0))
        #expect((analysis?.idleDuration ?? 0) >= 30)
        #expect((analysis?.directionConfidence ?? 0) > 0.5)
        #expect(Set(analysis?.mapSegments.map(\.direction) ?? []) == Set(WindRouteDirection.allTestDirections))
    }

    @Test func detectsStraightTacksWithoutCrossingOrLoop() {
        let analysis = analyzeWindRoute(from: Self.syntheticUpDownwindRoute())

        #expect(analysis?.turnAngles.count ?? 0 >= 4)
        #expect((analysis?.averageTurnAngle ?? 0) > 70)
        #expect((analysis?.averageTurnAngle ?? 180) < 90)
        #expect((analysis?.bestTurnAngle ?? 0) >= (analysis?.averageTurnAngle ?? 180))
        #expect(analysis?.angleMarkers.count == analysis?.turnAngles.count)
        #expect(analysis?.angleMarkers.allSatisfy { marker in
            let incomingLength = Self.distance(from: marker.incomingTurnPoint, to: marker.incomingPoint)
            let outgoingLength = Self.distance(from: marker.outgoingTurnPoint, to: marker.outgoingPoint)
            return abs(incomingLength - 120) < 1 && abs(outgoingLength - 120) < 1
        } == true)
    }

    @Test func rejectsWideRayAngleFromAShallowCourseBend() {
        let original = analyzeWindRoute(from: Self.syntheticUpDownwindRoute())
        let bentRoute = analyzeWindRoute(from: Self.syntheticUpDownwindRoute(includesSameSideCorner: true))

        #expect(bentRoute != nil)
        #expect((bentRoute?.turnAngles.count ?? 0) <= (original?.turnAngles.count ?? 0))
        #expect(bentRoute?.turnAngles.allSatisfy { (20...90).contains($0) } == true)
        #expect(bentRoute?.angleMarkers.count == bentRoute?.turnAngles.count)
    }

    @Test func detectsConnectedShortTacksAfterLongUpwindLegs() {
        let original = analyzeWindRoute(from: Self.syntheticUpDownwindRoute())
        let shortTacks = analyzeWindRoute(from: Self.syntheticUpDownwindRoute(includesShortTacks: true))

        #expect(shortTacks != nil)
        #expect(shortTacks?.turnAngles.count == (original?.turnAngles.count ?? 0) + 3)
        #expect(shortTacks?.turnAngles.suffix(3).allSatisfy { abs($0 - 80) < 3 } == true)
        #expect(shortTacks?.angleMarkers.count == shortTacks?.turnAngles.count)
    }

    @Test func separatesWavyDownwindModeFromTwoStraightUpwindModes() {
        let analysis = analyzeWindRoute(from: Self.syntheticThreeModeRoute())

        #expect(analysis != nil)
        #expect(analysis?.turnAngles.count == 5)
        #expect((analysis?.averageTurnAngle ?? 0) > 51)
        #expect((analysis?.averageTurnAngle ?? 90) < 57)
        #expect((analysis?.upwindDuration ?? 0) > (analysis?.downwindDuration ?? 0))
        #expect((analysis?.directionConfidence ?? 0) > 0.8)
    }

    @Test func upDownwindSportDefaultsToDirectionMap() {
        #expect(WorkoutType.paraUpDown.defaultStatisticsMapStyle == .windDirections)
    }

    @Test func keepsBriefStraightPumpingExcursionInDownwindRun() {
        let ordinary = analyzeWindRoute(from: Self.syntheticUpDownwindRoute())
        let analysis = analyzeWindRoute(from: Self.syntheticUpDownwindRoute(includesPumpingExcursion: true))

        #expect(analysis != nil)
        // The six real upwind legs total 270 seconds. Heading briefly upwind for
        // 20 seconds while pumping inside a downwind run must not create a new leg.
        #expect((analysis?.upwindDuration ?? .infinity) < 295)
        #expect((analysis?.downwindDuration ?? 0) > 190)
        #expect(analysis?.turnAngles.count == ordinary?.turnAngles.count)
    }

    @Test func rejectsOneWayRouteBecauseWindDirectionIsAmbiguous() {
        let locations = (0..<100).map { index in
            LocationData(
                timestamp: Date(timeIntervalSince1970: Double(index)),
                latitude: 47 + Double(index) * 0.00001,
                longitude: 7,
                speed: 3
            )
        }

        #expect(analyzeWindRoute(from: locations) == nil)
    }

    @Test func reversingDirectionsRecalculatesMapMetricsAndAngles() {
        let route = Self.syntheticUpDownwindRoute()
        let original = analyzeWindRoute(from: route)
        let reversed = analyzeWindRoute(from: route, reverseDirections: true)

        #expect(original != nil)
        #expect(reversed != nil)
        #expect((reversed?.upwindDuration ?? 0) < (original?.upwindDuration ?? 0))
        #expect((reversed?.downwindDuration ?? 0) > (original?.downwindDuration ?? 0))
        #expect(reversed?.mapSegments.contains(where: { $0.direction == .upwind }) == true)
        #expect(reversed?.turnAngles.isEmpty == true)
        #expect(reversed?.turnAngles != original?.turnAngles)
    }

    private static func syntheticUpDownwindRoute(
        includesPumpingExcursion: Bool = false,
        includesSameSideCorner: Bool = false,
        includesShortTacks: Bool = false
    ) -> [LocationData] {
        var result = [LocationData]()
        let origin = Date(timeIntervalSince1970: 0)
        var latitude = 47.0
        var longitude = 7.0
        var second = 0

        func append(seconds: Int, speed: Double, bearing: Double) {
            for _ in 0..<seconds {
                let radians = bearing * .pi / 180
                latitude += cos(radians) * speed / 111_111
                longitude += sin(radians) * speed / (111_111 * cos(latitude * .pi / 180))
                result.append(
                    LocationData(
                        timestamp: origin.addingTimeInterval(Double(second)),
                        latitude: latitude,
                        longitude: longitude,
                        speed: speed
                    )
                )
                second += 1
            }
        }

        append(seconds: 20, speed: 0, bearing: 0)
        // These are straight legs joined directly at tack corners: there is no
        // loop, gybe circle, or geometric crossing between the two leg lines.
        // They are deliberately faster so speed cannot override the geometry.
        for index in 0..<3 {
            append(seconds: 45, speed: 6, bearing: 40)
            if includesSameSideCorner, index == 0 {
                append(seconds: 8, speed: 6, bearing: 180)
                append(seconds: 45, speed: 6, bearing: 20)
            }
            append(seconds: 45, speed: 6, bearing: 300)
        }
        if includesShortTacks {
            // Each 192 m leg is below the long legs' median-based prominence
            // threshold, but the three successive 32 s corners are real tacks.
            append(seconds: 32, speed: 6, bearing: 40)
            append(seconds: 32, speed: 6, bearing: 300)
            append(seconds: 32, speed: 6, bearing: 40)
        }
        for index in 0..<3 {
            append(seconds: 30, speed: 4, bearing: 170)
            if includesPumpingExcursion, index == 0 {
                append(seconds: 20, speed: 4, bearing: 0)
            }
            append(seconds: 30, speed: 4, bearing: 190)
        }
        append(seconds: 20, speed: 0, bearing: 0)
        return result
    }

    private static func syntheticThreeModeRoute() -> [LocationData] {
        var result = [LocationData]()
        let origin = Date(timeIntervalSince1970: 0)
        var latitude = 47.0
        var longitude = 7.0
        var second = 0

        func append(seconds: Int, speed: Double, bearing: Double) {
            for _ in 0..<seconds {
                let radians = bearing * .pi / 180
                latitude += cos(radians) * speed / 111_111
                longitude += sin(radians) * speed / (111_111 * cos(latitude * .pi / 180))
                result.append(
                    LocationData(
                        timestamp: origin.addingTimeInterval(Double(second)),
                        latitude: latitude,
                        longitude: longitude,
                        speed: speed
                    )
                )
                second += 1
            }
        }

        func appendWavyDownwind(seconds: Int) {
            for index in 0..<(seconds / 8) {
                append(seconds: 8, speed: 5.5, bearing: index.isMultiple(of: 2) ? 15 : 100)
            }
        }

        append(seconds: 20, speed: 0, bearing: 0)
        append(seconds: 80, speed: 5.5, bearing: 217)
        append(seconds: 50, speed: 5.5, bearing: 343)
        appendWavyDownwind(seconds: 96)
        append(seconds: 80, speed: 5.5, bearing: 217)
        append(seconds: 50, speed: 5.5, bearing: 343)
        appendWavyDownwind(seconds: 96)
        append(seconds: 80, speed: 5.5, bearing: 217)
        append(seconds: 50, speed: 5.5, bearing: 343)
        append(seconds: 80, speed: 5.5, bearing: 217)
        append(seconds: 50, speed: 5.5, bearing: 343)
        appendWavyDownwind(seconds: 96)
        append(seconds: 20, speed: 0, bearing: 0)
        return result
    }

    private static func distance(from start: WindRouteCoordinate, to end: WindRouteCoordinate) -> Double {
        let latitudeMeters = (end.latitude - start.latitude) * 111_111
        let longitudeMeters = (end.longitude - start.longitude) * 111_111 * cos(start.latitude * .pi / 180)
        return hypot(latitudeMeters, longitudeMeters)
    }
}

private extension WindRouteDirection {
    static let allTestDirections: [WindRouteDirection] = [.upwind, .downwind, .idle]
}
