import Foundation
import Testing
@testable import _III_Water_Screenshots

struct WindRouteGPXRegressionTests {
    @Test func pendingUnusualSwellRouteRejectsTheFalseStraightLegAngle() {
        // Carqueiranne, 18 September: reported wind FROM 310°, swell FROM 220°.
        // Direction labels on several marked legs are still unresolved; see
        // WindRouteFixtures/Pending/Carqueiranne18Pending.md. This test only covers the
        // independently verified false-angle behavior.
        let analysis = Self.analyze("carqueiranne-2026-09-18", windFromBearing: 310)
        #expect(analysis.turnAngles.isEmpty)
        #expect(!analysis.angleMarkers.contains {
            Self.distance(from: ($0.vertex.latitude, $0.vertex.longitude),
                          to: (43.068485, 6.049266)) < 30
        })
    }

    @Test func carqueiranneSeventeenthKeepsItsCleanTacksAndEastwardDownwindRuns() {
        let analysis = Self.analyze("carqueiranne-2026-09-17")
        #expect(Self.direction(near: (43.081934, 6.067626), in: analysis) == .downwind)
        #expect(Self.direction(near: (43.068025, 6.047855), in: analysis) == .upwind)
        #expect(analysis.turnAngles.count >= 17)
        #expect(analysis.turnAngles.filter { (50...70).contains($0) }.count >= 17)
        #expect(analysis.angleMarkers.contains {
            Self.distance(from: ($0.vertex.latitude, $0.vertex.longitude),
                          to: (43.073153, 6.054232)) < 30
        })
        #expect(analysis.angleMarkers.contains {
            Self.distance(from: ($0.vertex.latitude, $0.vertex.longitude),
                          to: (43.077236, 6.081494)) < 30
        })
    }

    @Test func carqueiranneSixteenthKeepsThePreviouslyConfirmedAngles() {
        let analysis = Self.analyze("carqueiranne-2026-09-16")
        #expect(Self.direction(near: (43.074537, 6.061089), in: analysis) == .upwind)
        #expect(Self.direction(near: (43.079328, 6.059131), in: analysis) == .downwind)
        #expect(analysis.turnAngles.count >= 8)
    }

    @Test func previousLakesideRoutesKeepTheirDirectionsAndTurns() {
        let yverdon = Self.analyze("yverdon-2026-07-09")
        #expect(Self.direction(near: (46.803840, 6.649231), in: yverdon) == .upwind)
        #expect(Self.direction(near: (46.795016, 6.660411), in: yverdon) == .downwind)
        #expect(yverdon.turnAngles.count >= 3)

        let biel = Self.analyze("biel-2026-08-18")
        #expect(biel.turnAngles.count >= 5)

        let ipsach = Self.analyze("ipsach-2026-06-06")
        #expect(ipsach.turnAngles.count >= 12)
    }

    @Test func everyReportedAngleMatchesTheDrawnRays() {
        let routes = [
            Self.analyze("carqueiranne-2026-09-16"),
            Self.analyze("carqueiranne-2026-09-17"),
            Self.analyze("carqueiranne-2026-09-18", windFromBearing: 310),
            Self.analyze("biel-2026-08-18"),
            Self.analyze("ipsach-2026-06-06"),
            Self.analyze("yverdon-2026-07-09")
        ]
        for route in routes {
            for marker in route.angleMarkers {
                #expect((20...90).contains(marker.angle))
                #expect(abs(Self.drawnRayAngle(marker) - marker.angle) < 1)
            }
        }
    }

    private static func analyze(
        _ name: String,
        windFromBearing: Double? = nil
    ) -> WindRouteAnalysis {
        let fileURL = Bundle.main.url(forResource: name, withExtension: "csv")!
        let text = try! String(contentsOf: fileURL, encoding: .utf8)
        let locations = text.split(whereSeparator: \.isNewline).compactMap { line -> LocationData? in
            guard !line.hasPrefix("#") else { return nil }
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let seconds = Double(fields[0]),
                  let latitude = Double(fields[1]),
                  let longitude = Double(fields[2]),
                  let speed = Double(fields[3]) else { return nil }
            return LocationData(
                timestamp: Date(timeIntervalSince1970: seconds),
                latitude: latitude,
                longitude: longitude,
                speed: speed
            )
        }
        return analyzeWindRoute(from: locations, windFromBearing: windFromBearing)!
    }

    private static func direction(
        near point: (Double, Double),
        in analysis: WindRouteAnalysis
    ) -> WindRouteDirection? {
        let candidates = analysis.mapSegments.flatMap { segment in
            segment.coordinates.map { coordinate in
                (direction: segment.direction,
                 distance: distance(from: point, to: (coordinate.latitude, coordinate.longitude)))
            }
        }
        guard let nearest = candidates.min(by: { $0.distance < $1.distance }),
              nearest.distance < 20 else { return nil }
        return nearest.direction
    }

    private static func distance(
        from a: (Double, Double),
        to b: (Double, Double)
    ) -> Double {
        let north = (b.0 - a.0) * 111_111
        let east = (b.1 - a.1) * 111_111 * cos(a.0 * .pi / 180)
        return hypot(north, east)
    }

    private static func drawnRayAngle(_ marker: WindRouteAngleMarker) -> Double {
        let incomingEast = (marker.incomingPoint.longitude - marker.incomingTurnPoint.longitude)
            * cos(marker.incomingTurnPoint.latitude * .pi / 180)
        let incomingNorth = marker.incomingPoint.latitude - marker.incomingTurnPoint.latitude
        let outgoingEast = (marker.outgoingPoint.longitude - marker.outgoingTurnPoint.longitude)
            * cos(marker.outgoingTurnPoint.latitude * .pi / 180)
        let outgoingNorth = marker.outgoingPoint.latitude - marker.outgoingTurnPoint.latitude
        let dot = incomingEast * outgoingEast + incomingNorth * outgoingNorth
        let lengths = hypot(incomingEast, incomingNorth) * hypot(outgoingEast, outgoingNorth)
        return acos(min(1, max(-1, dot / lengths))) * 180 / .pi
    }
}
