#if os(iOS)
import Project7IIIScreenshots
import CoreLocation
import MapKit
import SwiftUI

let defaultScreenshotOption: AppScreenshotConfiguration.Option = .locale([Locale(identifier: "en")])

private final class ScreenshotBundleLocator {}

private struct ScreenshotTextBoundsKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        let rawSeed = UInt64(bitPattern: Int64(seed))
        state = rawSeed == 0 ? 0x9E3779B97F4A7C15 : rawSeed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private struct WigglePoint: Identifiable {
    let id = UUID()
    let point: CGPoint
    let color: Color
}

private let screenshotNeonRouteColor = Color(.displayP3, red: 0.922, green: 0.996, blue: 0.322, opacity: 1)

private struct NeonWiggleRoute: View {
    let seed: Int
    let canvasSize: CGSize
    let textSafeRect: CGRect
    let deviceRect: CGRect
    var showsLine = true
    var showsMarkers = true

    var body: some View {
        let points = makePoints()

        ZStack {
            if showsLine {
                routePath(points: points)
                    .stroke(screenshotNeonRouteColor, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }

            if showsMarkers {
                ForEach([points.first, points.last].compactMap { $0 }) { marker in
                    Circle()
                        .fill(marker.color)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 8)
                        }
                        .frame(width: 44, height: 44)
                        .position(marker.point)
                }
            }
        }
    }

    private func routePath(points: [WigglePoint]) -> Path {
        Path { path in
            let routePoints = points.map(\.point)
            guard let first = routePoints.first else { return }
            path.move(to: first)

            guard routePoints.count > 1 else { return }
            guard routePoints.count > 2 else {
                path.addLine(to: routePoints[1])
                return
            }

            let firstMidpoint = midpoint(routePoints[0], routePoints[1])
            path.addLine(to: firstMidpoint)

            for index in 1..<(routePoints.count - 1) {
                let current = routePoints[index]
                let next = routePoints[index + 1]
                let mid = midpoint(current, next)
                path.addQuadCurve(to: mid, control: current)
            }

            path.addQuadCurve(to: routePoints.last!, control: routePoints.last!)
        }
    }

    private func makePoints() -> [WigglePoint] {
        var generator = SeededGenerator(seed: seed)
        let surpriseStyle = SurpriseStyle.allCases.randomElement(using: &generator) ?? .slingshot
        let markerRadius: CGFloat = 24
        let minimumEndpointDistance = max(
            min(canvasSize.width * 0.48, diagonalDistance() * 0.5),
            420
        )
        let textKeepOut = textSafeRect == .zero
            ? .null
            : adjustedRect(textSafeRect, left: -24, right: -24, top: -20, bottom: -4)
        let deviceMarkerKeepOut = deviceRect.isEmpty
            ? .null
            : deviceRect
        let textPathKeepOut = textSafeRect == .zero
            ? .null
            : adjustedRect(textSafeRect, left: -8, right: -8, top: -8, bottom: -8)
        let markerKeepOutRects = [
            textKeepOut,
            deviceMarkerKeepOut
        ].filter { !$0.isNull && !$0.isEmpty }
        let pathKeepOutRects = [
            textPathKeepOut
        ].filter { !$0.isNull && !$0.isEmpty }
        let margin: CGFloat = 16
        let deviceCandidates = deviceMarkerCandidates(
            margin: margin,
            style: surpriseStyle,
            generator: &generator
        )
        let surpriseCandidates = surpriseMarkerCandidates(
            margin: margin,
            style: surpriseStyle,
            generator: &generator
        )
        let visibleDeviceCandidates = deviceCandidates.filter {
            isVisibleMarker($0, forbiddenRects: markerKeepOutRects, margin: margin, radius: markerRadius)
        }
        let visibleSurpriseCandidates = surpriseCandidates.filter {
            isVisibleMarker($0, forbiddenRects: markerKeepOutRects, margin: margin, radius: markerRadius)
        }

        let devicePoint = selectedDeviceMarkerPoint(
            visibleDeviceCandidates: visibleDeviceCandidates,
            deviceCandidates: deviceCandidates,
            forbiddenRects: markerKeepOutRects,
            margin: margin,
            radius: markerRadius,
            generator: &generator
        )
        let remotePoint = selectedRemoteMarkerPoint(
            anchorPoint: devicePoint,
            visibleSurpriseCandidates: visibleSurpriseCandidates,
            surpriseCandidates: surpriseCandidates,
            forbiddenRects: markerKeepOutRects,
            margin: margin,
            radius: markerRadius,
            minimumDistance: minimumEndpointDistance,
            generator: &generator
        )
        let minimumPlacementDistance: CGFloat = 300
        let upperGapRange = upperGapMarkerYRange(
            textKeepOut: textKeepOut,
            markerRadius: markerRadius
        )
        let upperGapCandidates = upperGapMarkerCandidates(
            textKeepOut: textKeepOut,
            markerRadius: markerRadius,
            margin: margin,
            generator: &generator
        )
        let visibleUpperGapCandidates = upperGapCandidates.filter {
            isVisibleMarker($0, forbiddenRects: markerKeepOutRects, margin: margin, radius: markerRadius)
        }
        let prioritizedVisibleDeviceCandidates = prioritizedDeviceCandidates(
            visibleDeviceCandidates,
            generator: &generator
        )
        let anchoredUpperGapAvailable = !(visibleUpperGapCandidates.isEmpty ? upperGapCandidates.isEmpty : false)
        let anchoredDeviceAvailable = !prioritizedVisibleDeviceCandidates.isEmpty || !deviceRect.isEmpty
        let anchorMode: EndpointAnchorMode?
        switch (anchoredUpperGapAvailable, anchoredDeviceAvailable) {
        case (true, true):
            anchorMode = Bool.random(using: &generator) ? .upperGap : .nearDevice
        case (true, false):
            anchorMode = .upperGap
        case (false, true):
            anchorMode = .nearDevice
        default:
            anchorMode = nil
        }
        let startPoint: CGPoint
        let endPoint: CGPoint

        if let anchorMode {
            let anchoredPoint: CGPoint
            let companionCandidates: [CGPoint]

            switch anchorMode {
            case .upperGap:
                let upperPool = visibleUpperGapCandidates.isEmpty ? upperGapCandidates : visibleUpperGapCandidates
                anchoredPoint = upperPool.randomElement(using: &generator) ?? remotePoint
                companionCandidates = ([devicePoint, remotePoint] + visibleSurpriseCandidates + prioritizedVisibleDeviceCandidates)
                    .filter { candidate in
                        candidate != anchoredPoint
                            && !(upperGapRange?.contains(candidate.y) ?? false)
                    }
            case .nearDevice:
                anchoredPoint = prioritizedVisibleDeviceCandidates.prefix(6).randomElement(using: &generator) ?? devicePoint
                companionCandidates = ([remotePoint] + visibleUpperGapCandidates + visibleSurpriseCandidates)
                    .filter { candidate in
                        candidate != anchoredPoint && !isNearDeviceCandidate(candidate)
                    }
            }

            if let companionPoint = selectedCompanionPoint(
                anchorPoint: anchoredPoint,
                candidates: companionCandidates,
                minimumDistance: max(220, minimumPlacementDistance * 0.68),
                avoidRect: textPathKeepOut,
                generator: &generator
            ) {
                let startIsAnchor = Bool.random(using: &generator)
                startPoint = startIsAnchor ? anchoredPoint : companionPoint
                endPoint = startIsAnchor ? companionPoint : anchoredPoint
            } else {
                let startNearDevice = Bool.random(using: &generator)
                startPoint = startNearDevice ? devicePoint : remotePoint
                endPoint = startNearDevice ? remotePoint : devicePoint
            }
        } else {
            var upperCandidates = [CGPoint]()
            upperCandidates.append(contentsOf: upperGapCandidates)

            let edgeMinX = margin + markerRadius + 20
            let edgeMaxX = canvasSize.width - margin - markerRadius - 20
            let edgeMaxY = max(
                (textKeepOut.isNull ? canvasSize.height * 0.14 : textKeepOut.minY - 6),
                margin + markerRadius + 12
            )
            for _ in 0..<8 {
                upperCandidates.append(CGPoint(
                    x: CGFloat.random(in: edgeMinX...edgeMaxX, using: &generator),
                    y: CGFloat.random(
                        in: (margin + markerRadius + 10)...max(margin + markerRadius + 14, edgeMaxY),
                        using: &generator
                    )
                ))
            }

            upperCandidates.append(contentsOf: visibleSurpriseCandidates.filter {
                $0.y < canvasSize.height * 0.44 && !isNearDeviceCandidate($0)
            })

            let visibleUpper = upperCandidates.filter {
                isVisibleMarker($0, forbiddenRects: markerKeepOutRects, margin: margin, radius: markerRadius)
            }
            let pool = visibleUpper.isEmpty ? upperCandidates : visibleUpper

            if let pair = selectedCandidatePair(
                candidates: pool,
                minimumDistance: minimumPlacementDistance,
                preferredYRange: upperGapRange,
                avoidRect: textPathKeepOut,
                generator: &generator
            ) {
                let startIsFirst = Bool.random(using: &generator)
                startPoint = startIsFirst ? pair.0 : pair.1
                endPoint = startIsFirst ? pair.1 : pair.0
            } else {
                let startNearDevice = Bool.random(using: &generator)
                startPoint = startNearDevice ? devicePoint : remotePoint
                endPoint = startNearDevice ? remotePoint : devicePoint
            }
        }

        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let length = max(sqrt((deltaX * deltaX) + (deltaY * deltaY)), 1)
        let direction = CGPoint(x: deltaX / length, y: deltaY / length)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let distanceScale = max(1.0, pow(length / 600, 0.7))
        let turns = min(
            surpriseStyle.maxTurns,
            max(
                surpriseStyle.minTurns,
            (length / surpriseStyle.turnDistanceDivisor) * distanceScale
                + CGFloat.random(in: surpriseStyle.turnJitter, using: &generator)
            )
        )
        let pointCount = min(600, max(60, Int(length / 3) * Int(max(1.0, distanceScale * 0.7)) + Int.random(in: 0...24, using: &generator)))
        let lengthAmplitudeScale = 0.72 + 0.55 * min(1.0, max(0, (length - 220)) / 620)
        let amplitude = min(
            canvasSize.width * 0.22,
            max(canvasSize.width * 0.08, length * 0.16, surpriseStyle.minAmplitude * 2.8)
        ) * lengthAmplitudeScale
        let shortRouteBoost = max(CGFloat.zero, min(1, (860 - length) / 460))
        let phase = CGFloat.random(in: 0...(2 * .pi), using: &generator)
        var routePoints = [startPoint]
        let microTurns = min(
            CGFloat(9.4),
            max(
                CGFloat(3.4) + shortRouteBoost * 1.4,
                turns * CGFloat.random(
                    in: (CGFloat(2.05) + shortRouteBoost * 0.40)...(CGFloat(2.75) + shortRouteBoost * 0.62),
                    using: &generator
                )
            )
        )

        let detourCenter = CGFloat.random(in: 0.28...0.72, using: &generator)
        let detourWindow = CGFloat.random(in: 0.24...0.34, using: &generator)
        let detourDirection: CGFloat = Bool.random(using: &generator) ? 1 : -1
        let detourStrength = min(
            canvasSize.width * 0.32,
            max(canvasSize.width * 0.14, length * 0.24, amplitude * CGFloat.random(in: 3.2...4.4, using: &generator))
        )
        let alongOffsetAmplitude = min(
            surpriseStyle.maxAlongOffset * 1.8,
            max(surpriseStyle.minAlongOffset * 1.4, length * surpriseStyle.alongOffsetFactor * 1.35)
        )
        let jitterLengthFactor = 1.25 + max(0, (length - 180) / 180)
        let alongJitterScale = alongOffsetAmplitude * (0.28 + shortRouteBoost * 0.16) * distanceScale * jitterLengthFactor
        let baseWiggleAmplitude = amplitude * CGFloat.random(in: 0.04...(0.08 + shortRouteBoost * 0.05), using: &generator)
        let curveBoostAmplitude = amplitude * CGFloat.random(in: (0.38 + shortRouteBoost * 0.14)...(0.58 + shortRouteBoost * 0.18), using: &generator)
        let secondaryWaveAmplitude = amplitude * CGFloat.random(in: 0.03...(0.07 + shortRouteBoost * 0.04), using: &generator)
        let driftAmplitude = amplitude * CGFloat.random(in: (0.12 + shortRouteBoost * 0.05)...(0.22 + shortRouteBoost * 0.08), using: &generator)
        let driftPhase = CGFloat.random(in: 0...(2 * .pi), using: &generator)
        let curveWindow = CGFloat.random(in: 2.2...3.2, using: &generator)
        let bigCurveCenter = microTurns * CGFloat.random(in: 0.40...0.60, using: &generator)
        let erraticCenter = min(max(detourCenter + CGFloat.random(in: -0.05...0.05, using: &generator), 0.18), 0.82)
        let erraticWindow = CGFloat.random(in: 0.12...0.19, using: &generator)
        let erraticCycles = CGFloat.random(in: 0.45...0.9, using: &generator)
        let erraticPhase = CGFloat.random(in: 0...(2 * .pi), using: &generator)
        let erraticLateralAmplitude = amplitude * CGFloat.random(in: (0.16 + shortRouteBoost * 0.08)...(0.24 + shortRouteBoost * 0.10), using: &generator) * jitterLengthFactor
        let erraticAlongAmplitude = alongOffsetAmplitude * CGFloat.random(in: (0.22 + shortRouteBoost * 0.08)...(0.34 + shortRouteBoost * 0.10), using: &generator) * jitterLengthFactor
        let backgroundLateralJitterScale = amplitude * (0.055 + shortRouteBoost * 0.035) * min(jitterLengthFactor, 3.2)
        let backgroundAlongJitterScale = alongJitterScale * (0.62 + shortRouteBoost * 0.18)
        let smoothingPasses = shortRouteBoost > 0.55 ? 3 : 5
        let minimumPointSpacing = max(CGFloat(110), CGFloat(300) - shortRouteBoost * 150)

        for index in 1..<pointCount {
            let progress = CGFloat(index) / CGFloat(pointCount)
            let basePoint = CGPoint(
                x: startPoint.x + deltaX * progress,
                y: startPoint.y + deltaY * progress
            )

            let cycleProgress = progress * microTurns
            var strongCurveEnvelope: CGFloat = 0
            let distanceFromCurve = abs((cycleProgress - bigCurveCenter) / curveWindow)
            if distanceFromCurve < 1 {
                strongCurveEnvelope = pow(
                    sin((1 - distanceFromCurve) * (.pi / 2)),
                    1.1
                )
            }

            var erraticEnvelope: CGFloat = 0
            let erraticDistance = abs((progress - erraticCenter) / erraticWindow)
            if erraticDistance < 1 {
                erraticEnvelope = pow(
                    sin((1 - erraticDistance) * (.pi / 2)),
                    0.7
                )
            }

            var lateralOffset = sin(cycleProgress * (.pi * 2) + phase) * (baseWiggleAmplitude + curveBoostAmplitude * strongCurveEnvelope)
            lateralOffset += sin(cycleProgress * (.pi * 2) * 0.34 + phase * 0.6) * secondaryWaveAmplitude * (0.3 + strongCurveEnvelope * 0.55)
            lateralOffset += sin(progress * .pi + driftPhase) * driftAmplitude
            lateralOffset += sin(((progress - erraticCenter) / max(erraticWindow, 0.001)) * (.pi * 2) * erraticCycles + erraticPhase)
                * erraticLateralAmplitude * erraticEnvelope
            lateralOffset += CGFloat.random(in: -backgroundLateralJitterScale...backgroundLateralJitterScale, using: &generator)
            var alongOffset = sin(progress * .pi + phase * 0.35) * alongOffsetAmplitude * 0.42
            alongOffset += sin(progress * (.pi * 2) * 0.32 + phase * 0.18) * alongOffsetAmplitude * 0.14
            alongOffset += cos(((progress - erraticCenter) / max(erraticWindow, 0.001)) * (.pi * 2) * erraticCycles + erraticPhase * 0.7)
                * erraticAlongAmplitude * erraticEnvelope
            alongOffset += CGFloat.random(in: -backgroundAlongJitterScale...backgroundAlongJitterScale, using: &generator)

            let detourProgress = abs((progress - detourCenter) / detourWindow)
            if detourProgress < 1 {
                let detourEnvelope = pow(sin((1 - detourProgress) * (.pi / 2)), 0.8)
                lateralOffset += detourDirection * detourStrength * detourEnvelope
                alongOffset += detourDirection * detourStrength * 0.14 * detourEnvelope
            }

            let rawPoint = CGPoint(
                x: basePoint.x + direction.x * alongOffset + perpendicular.x * lateralOffset,
                y: basePoint.y + direction.y * alongOffset + perpendicular.y * lateralOffset
            )
            let adjusted = adjustedPathPoint(
                rawPoint,
                keepOutRects: pathKeepOutRects,
                margin: margin
            )
            routePoints.append(adjusted)
        }

        routePoints.append(endPoint)
        routePoints = smoothedRoutePoints(
            routePoints,
            keepOutRects: pathKeepOutRects,
            margin: margin,
            passes: smoothingPasses
        )
        routePoints = minimumSpacingRoutePoints(
            routePoints,
            minimumDistance: minimumPointSpacing
        )

        return [
            WigglePoint(point: routePoints.first ?? startPoint, color: .green)
        ] + routePoints.dropFirst().dropLast().map {
            WigglePoint(point: $0, color: .clear)
        } + [
            WigglePoint(point: routePoints.last ?? endPoint, color: .red)
        ]
    }

    private func selectedDeviceMarkerPoint(
        visibleDeviceCandidates: [CGPoint],
        deviceCandidates: [CGPoint],
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat,
        generator: inout SeededGenerator
    ) -> CGPoint {
        let prioritizedVisibleCandidates = prioritizedDeviceCandidates(
            visibleDeviceCandidates,
            generator: &generator
        )
        if let preferredCandidate = prioritizedVisibleCandidates.first {
            return preferredCandidate
        }

        if let fallback = visibleMarkerPoint(
            candidates: prioritizedDeviceCandidates(deviceCandidates, generator: &generator),
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius
        ) {
            return fallback
        }

        return forcedFarMarkerPoint(
            awayFrom: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius,
            minimumDistance: 0
        )
    }

    private func selectedRemoteMarkerPoint(
        anchorPoint: CGPoint,
        visibleSurpriseCandidates: [CGPoint],
        surpriseCandidates: [CGPoint],
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat,
        minimumDistance: CGFloat,
        generator: inout SeededGenerator
    ) -> CGPoint {
        let farFromDeviceVisibleCandidates = visibleSurpriseCandidates.filter { !isNearDeviceCandidate($0) }
        let preferredVisibleCandidates: [CGPoint]
        if !farFromDeviceVisibleCandidates.isEmpty && CGFloat.random(in: 0...1, using: &generator) < 0.8 {
            preferredVisibleCandidates = farFromDeviceVisibleCandidates
        } else {
            preferredVisibleCandidates = visibleSurpriseCandidates
        }

        let rankedVisibleCandidates = preferredVisibleCandidates.sorted {
            distance(from: anchorPoint, to: $0) > distance(from: anchorPoint, to: $1)
        }

        if let maxDistance = rankedVisibleCandidates.first.map({ distance(from: anchorPoint, to: $0) }) {
            let nearBestThreshold = max(maxDistance * 0.76, minimumDistance)
            let candidatePool = rankedVisibleCandidates
                .prefix(40)
                .filter { distance(from: anchorPoint, to: $0) >= nearBestThreshold }

            if let chosenCandidate = Array(candidatePool).randomElement(using: &generator) {
                return chosenCandidate
            }

            let validVisibleCandidates = rankedVisibleCandidates
                .prefix(48)
                .filter { distance(from: anchorPoint, to: $0) >= minimumDistance }
            if let chosenCandidate = Array(validVisibleCandidates).randomElement(using: &generator) {
                return chosenCandidate
            }
        }

        let farFromDeviceFallbacks = surpriseCandidates.filter { !isNearDeviceCandidate($0) }
        let preferredFallbacks: [CGPoint]
        if !farFromDeviceFallbacks.isEmpty && CGFloat.random(in: 0...1, using: &generator) < 0.8 {
            preferredFallbacks = farFromDeviceFallbacks
        } else {
            preferredFallbacks = surpriseCandidates
        }

        let orderedFallbacks = preferredFallbacks
            .sorted { distance(from: anchorPoint, to: $0) > distance(from: anchorPoint, to: $1) }
        if let fallback = visibleMarkerPoint(
            candidates: orderedFallbacks,
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius,
            minimumDistanceFrom: anchorPoint,
            minimumDistance: minimumDistance
        ) {
            return fallback
        }

        return forcedFarMarkerPoint(
            awayFrom: anchorPoint,
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius,
            minimumDistance: minimumDistance
        )
    }

    private func prioritizedDeviceCandidates(
        _ candidates: [CGPoint],
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        let leftRightCandidates = candidates
            .filter { isHorizontalDeviceCandidate($0) }
            .shuffled(using: &generator)
        let aboveBelowCandidates = candidates
            .filter { !isHorizontalDeviceCandidate($0) }
            .shuffled(using: &generator)

        guard !leftRightCandidates.isEmpty, !aboveBelowCandidates.isEmpty else {
            return candidates.shuffled(using: &generator)
        }

        let prefersLeftRight = CGFloat.random(in: 0...1, using: &generator) < 0.75
        return prefersLeftRight
            ? leftRightCandidates + aboveBelowCandidates
            : aboveBelowCandidates + leftRightCandidates
    }

    private func isHorizontalDeviceCandidate(_ point: CGPoint) -> Bool {
        guard !deviceRect.isEmpty else { return false }
        let horizontalInset: CGFloat = 8
        return point.x <= deviceRect.minX - horizontalInset || point.x >= deviceRect.maxX + horizontalInset
    }

    private func isNearDeviceCandidate(_ point: CGPoint) -> Bool {
        guard !deviceRect.isEmpty else { return false }
        let relaxedDeviceZone = deviceRect.insetBy(dx: -170, dy: -150)
        return relaxedDeviceZone.contains(point)
    }

    private func upperGapMarkerYRange(
        textKeepOut: CGRect,
        markerRadius: CGFloat
    ) -> ClosedRange<CGFloat>? {
        let minY = (textKeepOut.isNull ? canvasSize.height * 0.16 : textKeepOut.maxY + markerRadius + 16)
        let maxY = (deviceRect.isEmpty ? canvasSize.height * 0.44 : deviceRect.minY - markerRadius - 18)
        guard maxY - minY >= 46 else { return nil }
        return minY...maxY
    }

    private func upperGapMarkerCandidates(
        textKeepOut: CGRect,
        markerRadius: CGFloat,
        margin: CGFloat,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        guard let yRange = upperGapMarkerYRange(textKeepOut: textKeepOut, markerRadius: markerRadius) else {
            return []
        }

        let minX = max(margin + markerRadius + 18, canvasSize.width * 0.18)
        let maxX = min(canvasSize.width - margin - markerRadius - 18, canvasSize.width * 0.82)
        guard maxX > minX else { return [] }

        let laneFractions: [CGFloat] = [0.0, 0.18, 0.34, 0.5, 0.66, 0.82, 1.0]
        let rowFractions: [CGFloat] = [0.12, 0.34, 0.58, 0.82]
        let width = maxX - minX
        let height = yRange.upperBound - yRange.lowerBound
        var candidates = [CGPoint]()

        for lane in laneFractions {
            for row in rowFractions {
                candidates.append(CGPoint(
                    x: min(max(minX + width * lane + CGFloat.random(in: -26...26, using: &generator), minX), maxX),
                    y: min(max(yRange.lowerBound + height * row + CGFloat.random(in: -14...14, using: &generator), yRange.lowerBound), yRange.upperBound)
                ))
            }
        }

        for _ in 0..<18 {
            candidates.append(CGPoint(
                x: CGFloat.random(in: minX...maxX, using: &generator),
                y: CGFloat.random(in: yRange, using: &generator)
            ))
        }

        return candidates
    }

    private func selectedCompanionPoint(
        anchorPoint: CGPoint,
        candidates: [CGPoint],
        minimumDistance: CGFloat,
        avoidRect: CGRect,
        generator: inout SeededGenerator
    ) -> CGPoint? {
        guard !candidates.isEmpty else { return nil }

        let scoredCandidates = candidates.map { candidate in
            let companionDistance = distance(from: anchorPoint, to: candidate)
            let xSeparation = abs(anchorPoint.x - candidate.x)
            let ySeparation = abs(anchorPoint.y - candidate.y)
            let edgeInset = min(candidate.x, canvasSize.width - candidate.x)
            let edgePenalty = max(0, canvasSize.width * 0.14 - edgeInset)
            let textCrossPenalty = segmentIntersectsRect(from: anchorPoint, to: candidate, rect: avoidRect) ? 180.0 : 0
            let score = companionDistance
                + xSeparation * 0.42
                - ySeparation * 0.14
                - edgePenalty * 2.2
                - textCrossPenalty

            return (candidate: candidate, distance: companionDistance, score: score)
        }

        let eligibleCandidates = scoredCandidates.filter { $0.distance >= minimumDistance }
        let pool = eligibleCandidates.isEmpty ? scoredCandidates : eligibleCandidates
        let bestCandidates = pool
            .sorted { $0.score > $1.score }
            .prefix(10)

        return Array(bestCandidates).randomElement(using: &generator)?.candidate
    }

    private func selectedCandidatePair(
        candidates: [CGPoint],
        minimumDistance: CGFloat,
        preferredYRange: ClosedRange<CGFloat>? = nil,
        avoidRect: CGRect = .null,
        generator: inout SeededGenerator
    ) -> (CGPoint, CGPoint)? {
        guard candidates.count > 1 else { return nil }

        var scoredPairs: [(first: CGPoint, second: CGPoint, distance: CGFloat, score: CGFloat)] = []
        for firstIndex in 0..<(candidates.count - 1) {
            for secondIndex in (firstIndex + 1)..<candidates.count {
                let first = candidates[firstIndex]
                let second = candidates[secondIndex]
                let pairDistance = distance(from: first, to: second)
                let xSeparation = abs(first.x - second.x)
                let ySeparation = abs(first.y - second.y)
                let edgeInset = min(
                    first.x,
                    canvasSize.width - first.x,
                    second.x,
                    canvasSize.width - second.x
                )
                let edgePenalty = max(0, canvasSize.width * 0.15 - edgeInset)
                let preferredCount = preferredYRange.map { range in
                    CGFloat([first, second].filter { range.contains($0.y) }.count)
                } ?? 0
                let upperBias = max(0, canvasSize.height * 0.46 - ((first.y + second.y) / 2)) * 0.12
                let textCrossPenalty = segmentIntersectsRect(from: first, to: second, rect: avoidRect) ? 170.0 : 0
                let score = pairDistance
                    + xSeparation * 0.55
                    - ySeparation * 0.2
                    - edgePenalty * 2.4
                    + preferredCount * 115
                    + upperBias
                    - textCrossPenalty
                scoredPairs.append((first, second, pairDistance, score))
            }
        }

        let eligiblePairs = scoredPairs.filter { $0.distance >= minimumDistance * 0.72 }
        let pairPool = eligiblePairs.isEmpty ? scoredPairs : eligiblePairs
        let topPairs = pairPool
            .sorted { $0.score > $1.score }
            .prefix(8)

        guard let selectedPair = Array(topPairs).randomElement(using: &generator) else {
            return nil
        }

        return (selectedPair.first, selectedPair.second)
    }

    private func visibleMarkerPoint(
        candidates: [CGPoint],
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat,
        minimumDistanceFrom anchorPoint: CGPoint? = nil,
        minimumDistance: CGFloat = 0
    ) -> CGPoint? {
        for candidate in candidates {
            let isFarEnough = anchorPoint.map { distance(from: candidate, to: $0) >= minimumDistance } ?? true
            if isFarEnough && isVisibleMarker(candidate, forbiddenRects: forbiddenRects, margin: margin, radius: radius) {
                return candidate
            }
        }

        for edgeInset in stride(from: margin, through: canvasSize.width * 0.3, by: 22) {
            let fallbackCandidates = [
                CGPoint(x: edgeInset, y: margin + radius + 10),
                CGPoint(x: canvasSize.width - edgeInset, y: margin + radius + 10),
                CGPoint(x: edgeInset, y: canvasSize.height - margin - radius - 10),
                CGPoint(x: canvasSize.width - edgeInset, y: canvasSize.height - margin - radius - 10),
                CGPoint(x: edgeInset, y: canvasSize.height * 0.5),
                CGPoint(x: canvasSize.width - edgeInset, y: canvasSize.height * 0.5)
            ]

            for fallback in fallbackCandidates {
                let isFarEnough = anchorPoint.map { distance(from: fallback, to: $0) >= minimumDistance } ?? true
                if isFarEnough && isVisibleMarker(fallback, forbiddenRects: forbiddenRects, margin: margin, radius: radius) {
                    return fallback
                }
            }
        }

        return nil
    }

    private func forcedFarMarkerPoint(
        awayFrom anchorPoint: CGPoint,
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat,
        minimumDistance: CGFloat
    ) -> CGPoint {
        let horizontalEdgeBuffer = max(radius + 16, margin)
        let verticalEdgeBuffer = max(margin + radius + 44, canvasSize.height * 0.045)
        let mirrored = CGPoint(
            x: min(max(canvasSize.width - anchorPoint.x, horizontalEdgeBuffer), canvasSize.width - horizontalEdgeBuffer),
            y: min(max(canvasSize.height - anchorPoint.y, verticalEdgeBuffer), canvasSize.height - verticalEdgeBuffer)
        )
        let edgeCandidates = [
            mirrored,
            CGPoint(x: horizontalEdgeBuffer, y: verticalEdgeBuffer),
            CGPoint(x: canvasSize.width - horizontalEdgeBuffer, y: verticalEdgeBuffer),
            CGPoint(x: horizontalEdgeBuffer, y: canvasSize.height - verticalEdgeBuffer),
            CGPoint(x: canvasSize.width - horizontalEdgeBuffer, y: canvasSize.height - verticalEdgeBuffer),
            CGPoint(x: horizontalEdgeBuffer, y: canvasSize.height * 0.5),
            CGPoint(x: canvasSize.width - horizontalEdgeBuffer, y: canvasSize.height * 0.5),
            CGPoint(x: canvasSize.width * 0.5, y: verticalEdgeBuffer),
            CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height - verticalEdgeBuffer)
        ]
        .sorted { distance(from: anchorPoint, to: $0) > distance(from: anchorPoint, to: $1) }

        if let visibleCandidate = visibleMarkerPoint(
            candidates: edgeCandidates,
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius,
            minimumDistanceFrom: anchorPoint,
            minimumDistance: minimumDistance
        ) {
            return visibleCandidate
        }

        return edgeCandidates.first ?? mirrored
    }

    private func isVisibleMarker(
        _ point: CGPoint,
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat
    ) -> Bool {
        let horizontalEdgeBuffer = max(radius + 16, margin)
        let verticalEdgeBuffer = max(margin + radius + 44, canvasSize.height * 0.045)
        guard point.x >= horizontalEdgeBuffer,
              point.x <= canvasSize.width - horizontalEdgeBuffer,
              point.y >= verticalEdgeBuffer,
              point.y <= canvasSize.height - verticalEdgeBuffer else {
            return false
        }

        let markerRect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        return forbiddenRects.allSatisfy { !$0.intersects(markerRect) }
    }

    private func adjustedPathPoint(
        _ point: CGPoint,
        keepOutRects: [CGRect],
        margin: CGFloat
    ) -> CGPoint {
        var adjusted = point

        for rect in keepOutRects where rect.contains(adjusted) {
            let pushLeft = adjusted.x - rect.minX
            let pushRight = rect.maxX - adjusted.x
            let pushUp = adjusted.y - rect.minY
            let pushDown = rect.maxY - adjusted.y
            let minPush = min(pushLeft, pushRight, pushUp, pushDown)

            let nudge = minPush + 4
            if minPush == pushLeft {
                adjusted.x -= nudge
            } else if minPush == pushRight {
                adjusted.x += nudge
            } else if minPush == pushUp {
                adjusted.y -= nudge
            } else {
                adjusted.y += nudge
            }
        }

        return adjusted
    }

    private func smoothedRoutePoints(
        _ points: [CGPoint],
        keepOutRects: [CGRect],
        margin: CGFloat,
        passes: Int = 5
    ) -> [CGPoint] {
        guard points.count > 3 else { return points }

        var smoothed = points
        for _ in 0..<max(0, passes) {
            var next = smoothed
            for index in 1..<(smoothed.count - 1) {
                let previous = smoothed[index - 1]
                let current = smoothed[index]
                let upcoming = smoothed[index + 1]
                let blended = CGPoint(
                    x: previous.x * 0.25 + current.x * 0.5 + upcoming.x * 0.25,
                    y: previous.y * 0.25 + current.y * 0.5 + upcoming.y * 0.25
                )
                next[index] = adjustedPathPoint(
                    blended,
                    keepOutRects: keepOutRects,
                    margin: margin
                )
            }
            smoothed = next
        }

        return smoothed
    }

    private func minimumSpacingRoutePoints(
        _ points: [CGPoint],
        minimumDistance: CGFloat
    ) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var filtered = [points[0]]
        for index in 1..<(points.count - 1) {
            let point = points[index]
            let nextPoint = points[index + 1]

            if let last = filtered.last,
               shouldKeepRoutePoint(
                previousKeptPoint: last,
                candidatePoint: point,
                nextPoint: nextPoint,
                minimumDistance: minimumDistance
               ) {
                filtered.append(point)
            }
        }

        if let lastPoint = points.last {
            if let previous = filtered.last, distance(from: previous, to: lastPoint) < minimumDistance {
                if filtered.count > 1 {
                    filtered.removeLast()
                }
            }
            filtered.append(lastPoint)
        }

        return filtered
    }

    private func shouldKeepRoutePoint(
        previousKeptPoint: CGPoint,
        candidatePoint: CGPoint,
        nextPoint: CGPoint,
        minimumDistance: CGFloat
    ) -> Bool {
        let distanceToPrevious = distance(from: previousKeptPoint, to: candidatePoint)
        if distanceToPrevious >= minimumDistance {
            return true
        }

        let turnPreservationDistance = max(150, minimumDistance * 0.52)
        guard distanceToPrevious >= turnPreservationDistance else { return false }

        let turnAngle = angleBetweenSegments(
            from: previousKeptPoint,
            through: candidatePoint,
            to: nextPoint
        )
        return turnAngle >= 0.42
    }

    private func angleBetweenSegments(
        from first: CGPoint,
        through second: CGPoint,
        to third: CGPoint
    ) -> CGFloat {
        let vector1 = CGPoint(x: second.x - first.x, y: second.y - first.y)
        let vector2 = CGPoint(x: third.x - second.x, y: third.y - second.y)
        let length1 = sqrt((vector1.x * vector1.x) + (vector1.y * vector1.y))
        let length2 = sqrt((vector2.x * vector2.x) + (vector2.y * vector2.y))
        guard length1 > 0.001, length2 > 0.001 else { return 0 }

        let normalizedDot = max(
            -1,
            min(1, ((vector1.x * vector2.x) + (vector1.y * vector2.y)) / (length1 * length2))
        )
        return acos(normalizedDot)
    }

    private func adjustedRect(
        _ rect: CGRect,
        left: CGFloat,
        right: CGFloat,
        top: CGFloat,
        bottom: CGFloat
    ) -> CGRect {
        CGRect(
            x: rect.minX + left,
            y: rect.minY + top,
            width: rect.width - left - right,
            height: rect.height - top - bottom
        )
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt((dx * dx) + (dy * dy))
    }

    private func segmentIntersectsRect(
        from first: CGPoint,
        to second: CGPoint,
        rect: CGRect
    ) -> Bool {
        guard !rect.isNull && !rect.isEmpty else { return false }
        if rect.contains(first) || rect.contains(second) {
            return true
        }

        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        return segmentsIntersect(first, second, topLeft, topRight)
            || segmentsIntersect(first, second, topRight, bottomRight)
            || segmentsIntersect(first, second, bottomRight, bottomLeft)
            || segmentsIntersect(first, second, bottomLeft, topLeft)
    }

    private func segmentsIntersect(
        _ firstStart: CGPoint,
        _ firstEnd: CGPoint,
        _ secondStart: CGPoint,
        _ secondEnd: CGPoint
    ) -> Bool {
        func cross(_ origin: CGPoint, _ pointA: CGPoint, _ pointB: CGPoint) -> CGFloat {
            (pointA.x - origin.x) * (pointB.y - origin.y) - (pointA.y - origin.y) * (pointB.x - origin.x)
        }

        func onSegment(_ point: CGPoint, _ segmentStart: CGPoint, _ segmentEnd: CGPoint) -> Bool {
            let epsilon: CGFloat = 0.0001
            return point.x >= min(segmentStart.x, segmentEnd.x) - epsilon
                && point.x <= max(segmentStart.x, segmentEnd.x) + epsilon
                && point.y >= min(segmentStart.y, segmentEnd.y) - epsilon
                && point.y <= max(segmentStart.y, segmentEnd.y) + epsilon
        }

        let d1 = cross(firstStart, firstEnd, secondStart)
        let d2 = cross(firstStart, firstEnd, secondEnd)
        let d3 = cross(secondStart, secondEnd, firstStart)
        let d4 = cross(secondStart, secondEnd, firstEnd)
        let epsilon: CGFloat = 0.0001

        if ((d1 > epsilon && d2 < -epsilon) || (d1 < -epsilon && d2 > epsilon))
            && ((d3 > epsilon && d4 < -epsilon) || (d3 < -epsilon && d4 > epsilon)) {
            return true
        }

        if abs(d1) <= epsilon && onSegment(secondStart, firstStart, firstEnd) { return true }
        if abs(d2) <= epsilon && onSegment(secondEnd, firstStart, firstEnd) { return true }
        if abs(d3) <= epsilon && onSegment(firstStart, secondStart, secondEnd) { return true }
        if abs(d4) <= epsilon && onSegment(firstEnd, secondStart, secondEnd) { return true }
        return false
    }

    private func diagonalDistance() -> CGFloat {
        sqrt((canvasSize.width * canvasSize.width) + (canvasSize.height * canvasSize.height))
    }

    private func deviceMarkerCandidates(
        margin: CGFloat,
        style: SurpriseStyle,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        guard !deviceRect.isEmpty else {
            return outerCanvasCandidates(margin: margin, generator: &generator)
        }

        let preferredSides = style.deviceSides
        var candidates = rectCornerCandidates(
            around: deviceRect,
            offsetRange: style.deviceCornerOffsetRange,
            margin: margin,
            generator: &generator
        )
        candidates.append(contentsOf: rectSideCandidates(
            around: deviceRect,
            sides: preferredSides,
            offset: style.deviceSideOffset,
            margin: margin,
            samplesPerSide: style.deviceSamplesPerSide,
            generator: &generator
        ))
        candidates.append(contentsOf: horizontalDeviceCandidates(
            around: deviceRect,
            offsetRange: style.horizontalDeviceOffsetRange,
            margin: margin,
            generator: &generator
        ))
        candidates.append(contentsOf: orbitalCandidates(
            around: deviceRect,
            angles: style.deviceOrbitAngles,
            offsetRange: style.deviceOrbitOffsetRange,
            jitter: style.deviceOrbitJitter,
            margin: margin,
            generator: &generator
        ))

        return candidates.shuffled(using: &generator)
    }

    private func surpriseMarkerCandidates(
        margin: CGFloat,
        style: SurpriseStyle,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        var candidates = outerCanvasCandidates(margin: margin, generator: &generator)
        candidates.append(contentsOf: edgeScatterCandidates(
            margin: margin,
            count: style.edgeScatterCount,
            generator: &generator
        ))
        candidates.append(contentsOf: canvasCornerBurstCandidates(margin: margin, generator: &generator))

        if textSafeRect != .zero && !textSafeRect.isEmpty {
            candidates.append(contentsOf: rectCornerCandidates(
                around: textSafeRect,
                offsetRange: style.textCornerOffsetRange,
                margin: margin,
                generator: &generator
            ))
            candidates.append(contentsOf: rectSideCandidates(
                around: textSafeRect,
                sides: style.textSides,
                offset: style.textSideOffset,
                margin: margin,
                samplesPerSide: style.textSamplesPerSide,
                generator: &generator
            ))
        }

        if !deviceRect.isEmpty {
            candidates.append(contentsOf: orbitalCandidates(
                around: deviceRect,
                angles: style.remoteOrbitAngles,
                offsetRange: style.remoteOrbitOffsetRange,
                jitter: style.remoteOrbitJitter,
                margin: margin,
                generator: &generator
            ))
        }

        return candidates.shuffled(using: &generator)
    }

    private func outerCanvasCandidates(margin: CGFloat, generator: inout SeededGenerator) -> [CGPoint] {
        let innerMinX = margin + 10
        let innerMaxX = canvasSize.width - margin - 10
        let innerMinY = margin + 10
        let innerMaxY = canvasSize.height - margin - 10
        let horizontalRange = innerMinX...innerMaxX
        let verticalRange = innerMinY...innerMaxY

        return [
            CGPoint(x: innerMinX, y: innerMinY),
            CGPoint(x: innerMaxX, y: innerMinY),
            CGPoint(x: innerMinX, y: innerMaxY),
            CGPoint(x: innerMaxX, y: innerMaxY),
            CGPoint(x: innerMinX, y: CGFloat.random(in: verticalRange, using: &generator)),
            CGPoint(x: innerMaxX, y: CGFloat.random(in: verticalRange, using: &generator)),
            CGPoint(x: CGFloat.random(in: horizontalRange, using: &generator), y: innerMinY),
            CGPoint(x: CGFloat.random(in: horizontalRange, using: &generator), y: innerMaxY)
        ]
    }

    private func rectSideCandidates(
        around rect: CGRect,
        sides: [CandidateSide],
        offset: CGFloat,
        margin: CGFloat,
        samplesPerSide: Int,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        var candidates: [CGPoint] = []

        for side in sides {
            for _ in 0..<samplesPerSide {
                let extraOffset = CGFloat.random(in: 0...34, using: &generator)
                switch side {
                case .left:
                    candidates.append(
                        CGPoint(
                            x: rect.minX - offset - extraOffset,
                            y: CGFloat.random(
                                in: max(margin, rect.minY - rect.height * 0.18)...min(canvasSize.height - margin, rect.maxY + rect.height * 0.18),
                                using: &generator
                            )
                        )
                    )
                case .right:
                    candidates.append(
                        CGPoint(
                            x: rect.maxX + offset + extraOffset,
                            y: CGFloat.random(
                                in: max(margin, rect.minY - rect.height * 0.18)...min(canvasSize.height - margin, rect.maxY + rect.height * 0.18),
                                using: &generator
                            )
                        )
                    )
                case .top:
                    candidates.append(
                        CGPoint(
                            x: CGFloat.random(
                                in: max(margin, rect.minX - rect.width * 0.16)...min(canvasSize.width - margin, rect.maxX + rect.width * 0.16),
                                using: &generator
                            ),
                            y: rect.minY - offset - extraOffset
                        )
                    )
                case .bottom:
                    candidates.append(
                        CGPoint(
                            x: CGFloat.random(
                                in: max(margin, rect.minX - rect.width * 0.16)...min(canvasSize.width - margin, rect.maxX + rect.width * 0.16),
                                using: &generator
                            ),
                            y: rect.maxY + offset + extraOffset
                        )
                    )
                }
            }
        }

        return candidates
    }

    private func edgeScatterCandidates(margin: CGFloat, count: Int, generator: inout SeededGenerator) -> [CGPoint] {
        guard count > 0 else { return [] }

        let minX = margin
        let maxX = canvasSize.width - margin
        let minY = margin
        let maxY = canvasSize.height - margin

        return (0..<count).map { _ in
            switch Int.random(in: 0...3, using: &generator) {
            case 0:
                return CGPoint(x: CGFloat.random(in: minX...maxX, using: &generator), y: minY)
            case 1:
                return CGPoint(x: maxX, y: CGFloat.random(in: minY...maxY, using: &generator))
            case 2:
                return CGPoint(x: CGFloat.random(in: minX...maxX, using: &generator), y: maxY)
            default:
                return CGPoint(x: minX, y: CGFloat.random(in: minY...maxY, using: &generator))
            }
        }
    }

    private func canvasCornerBurstCandidates(margin: CGFloat, generator: inout SeededGenerator) -> [CGPoint] {
        let inset: CGFloat = 6
        let minX = margin + inset
        let maxX = canvasSize.width - margin - inset
        let minY = margin + inset
        let maxY = canvasSize.height - margin - inset

        return [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: canvasSize.height * CGFloat.random(in: 0.18...0.82, using: &generator)),
            CGPoint(x: maxX, y: canvasSize.height * CGFloat.random(in: 0.18...0.82, using: &generator)),
            CGPoint(x: canvasSize.width * CGFloat.random(in: 0.14...0.86, using: &generator), y: minY),
            CGPoint(x: canvasSize.width * CGFloat.random(in: 0.14...0.86, using: &generator), y: maxY)
        ]
    }

    private func rectCornerCandidates(
        around rect: CGRect,
        offsetRange: ClosedRange<CGFloat>,
        margin: CGFloat,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]

        return corners.map { corner in
            let offsetX = CGFloat.random(in: offsetRange, using: &generator) * (corner.x < rect.midX ? -1 : 1)
            let offsetY = CGFloat.random(in: offsetRange, using: &generator) * (corner.y < rect.midY ? -1 : 1)
            let jitterX = CGFloat.random(in: -8...8, using: &generator)
            let jitterY = CGFloat.random(in: -8...8, using: &generator)

            return CGPoint(
                x: min(max(corner.x + offsetX + jitterX, margin), canvasSize.width - margin),
                y: min(max(corner.y + offsetY + jitterY, margin), canvasSize.height - margin)
            )
        }
    }

    private func orbitalCandidates(
        around rect: CGRect,
        angles: [CGFloat],
        offsetRange: ClosedRange<CGFloat>,
        jitter: CGFloat,
        margin: CGFloat,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadiusX = rect.width / 2
        let baseRadiusY = rect.height / 2

        return angles.map { normalizedAngle in
            let angle = normalizedAngle * .pi + CGFloat.random(in: -0.09...0.09, using: &generator)
            let offset = CGFloat.random(in: offsetRange, using: &generator)
            let radiusX = baseRadiusX + offset + CGFloat.random(in: -jitter...jitter, using: &generator)
            let radiusY = baseRadiusY + offset + CGFloat.random(in: -jitter...jitter, using: &generator)

            return CGPoint(
                x: min(max(center.x + cos(angle) * radiusX, margin), canvasSize.width - margin),
                y: min(max(center.y + sin(angle) * radiusY, margin), canvasSize.height - margin)
            )
        }
    }

    private func horizontalDeviceCandidates(
        around rect: CGRect,
        offsetRange: ClosedRange<CGFloat>,
        margin: CGFloat,
        generator: inout SeededGenerator
    ) -> [CGPoint] {
        let verticalBand = max(18, rect.height * 0.22)
        let leftXBase = rect.minX
        let rightXBase = rect.maxX

        return (0..<10).map { index in
            let placeLeft = index < 5
            let xOffset = CGFloat.random(in: offsetRange, using: &generator)
            let yJitter = CGFloat.random(in: -verticalBand...verticalBand, using: &generator)

            return CGPoint(
                x: min(
                    max((placeLeft ? leftXBase - xOffset : rightXBase + xOffset), margin),
                    canvasSize.width - margin
                ),
                y: min(max(rect.midY + yJitter, margin), canvasSize.height - margin)
            )
        }
    }

    private enum CandidateSide {
        case left
        case right
        case top
        case bottom
    }

    private enum EndpointAnchorMode {
        case upperGap
        case nearDevice
    }

    private enum SurpriseStyle: CaseIterable {
        case slingshot
        case sideSwipe
        case basementDive
        case cornerChaos
        case halo

        var deviceSides: [CandidateSide] {
            switch self {
            case .slingshot:
                return [.left, .left, .right, .right, .bottom]
            case .sideSwipe:
                return [.left, .left, .left, .right, .right]
            case .basementDive:
                return [.left, .right, .bottom, .bottom]
            case .cornerChaos:
                return [.left, .left, .right, .right, .bottom, .top]
            case .halo:
                return [.left, .left, .right, .right, .top]
            }
        }

        var deviceCornerOffsetRange: ClosedRange<CGFloat> {
            switch self {
            case .slingshot: return 6...18
            case .sideSwipe: return 10...22
            case .basementDive: return 8...20
            case .cornerChaos: return 4...28
            case .halo: return 10...26
            }
        }

        var deviceSideOffset: CGFloat {
            switch self {
            case .slingshot: return 14
            case .sideSwipe: return 12
            case .basementDive: return 10
            case .cornerChaos: return 18
            case .halo: return 16
            }
        }

        var deviceSamplesPerSide: Int {
            switch self {
            case .cornerChaos: return 4
            case .sideSwipe: return 4
            default: return 3
            }
        }

        var deviceOrbitAngles: [CGFloat] {
            switch self {
            case .slingshot:
                return [0.18, 0.32, 0.82, 1.18, 1.68, 1.82]
            case .sideSwipe:
                return [0.04, 0.12, 0.18, 0.82, 1.18, 1.82, 1.88]
            case .basementDive:
                return [0.18, 0.42, 0.58, 1.42, 1.58, 1.82]
            case .cornerChaos:
                return [0.06, 0.18, 0.32, 0.50, 0.82, 1.18, 1.50, 1.68, 1.82, 1.94]
            case .halo:
                return [0.0, 0.12, 0.18, 0.82, 1.0, 1.18, 1.82, 1.88]
            }
        }

        var deviceOrbitOffsetRange: ClosedRange<CGFloat> {
            switch self {
            case .slingshot: return 8...24
            case .sideSwipe: return 8...28
            case .basementDive: return 10...26
            case .cornerChaos: return 6...34
            case .halo: return 12...30
            }
        }

        var deviceOrbitJitter: CGFloat {
            switch self {
            case .cornerChaos: return 14
            default: return 10
            }
        }

        var horizontalDeviceOffsetRange: ClosedRange<CGFloat> {
            switch self {
            case .slingshot: return 10...24
            case .sideSwipe: return 8...22
            case .basementDive: return 12...26
            case .cornerChaos: return 6...30
            case .halo: return 10...24
            }
        }

        var remoteOrbitAngles: [CGFloat] {
            switch self {
            case .slingshot:
                return [0.06, 0.16, 0.26, 0.92, 1.08, 1.22, 1.78, 1.92]
            case .sideSwipe:
                return [0.46, 0.56, 1.46, 1.56, 0.06, 1.06]
            case .basementDive:
                return [0.96, 1.06, 1.16, 1.26, 1.74, 1.84]
            case .cornerChaos:
                return [0.04, 0.18, 0.32, 0.46, 0.60, 0.74, 1.04, 1.18, 1.32, 1.46, 1.60, 1.74]
            case .halo:
                return [0.10, 0.30, 0.50, 0.70, 0.90, 1.10, 1.30, 1.50, 1.70, 1.90]
            }
        }

        var remoteOrbitOffsetRange: ClosedRange<CGFloat> {
            switch self {
            case .slingshot: return 120...220
            case .sideSwipe: return 110...210
            case .basementDive: return 130...240
            case .cornerChaos: return 96...230
            case .halo: return 100...200
            }
        }

        var remoteOrbitJitter: CGFloat {
            switch self {
            case .cornerChaos: return 28
            default: return 18
            }
        }

        var textSides: [CandidateSide] {
            switch self {
            case .slingshot: return [.left, .right]
            case .sideSwipe: return [.left, .right, .top]
            case .basementDive: return [.left, .right, .bottom]
            case .cornerChaos: return [.left, .right, .top, .bottom]
            case .halo: return [.left, .right, .top, .bottom]
            }
        }

        var textCornerOffsetRange: ClosedRange<CGFloat> {
            switch self {
            case .cornerChaos: return 14...62
            default: return 18...52
            }
        }

        var textSideOffset: CGFloat {
            switch self {
            case .slingshot: return 26
            case .sideSwipe: return 34
            case .basementDive: return 30
            case .cornerChaos: return 24
            case .halo: return 28
            }
        }

        var textSamplesPerSide: Int {
            switch self {
            case .cornerChaos: return 4
            default: return 3
            }
        }

        var edgeScatterCount: Int {
            switch self {
            case .cornerChaos: return 16
            case .basementDive: return 14
            default: return 12
            }
        }

        var minTurns: CGFloat {
            switch self {
            case .basementDive: return 1.2
            default: return 1.35
            }
        }

        var maxTurns: CGFloat {
            switch self {
            case .cornerChaos: return 4.8
            case .halo: return 4.5
            default: return 4.0
            }
        }

        var turnDistanceDivisor: CGFloat {
            switch self {
            case .basementDive: return 320
            case .sideSwipe: return 300
            case .slingshot: return 280
            case .cornerChaos: return 260
            case .halo: return 270
            }
        }

        var turnJitter: ClosedRange<CGFloat> {
            switch self {
            case .basementDive: return 0.04...0.40
            case .cornerChaos: return 0.10...0.78
            default: return 0.08...0.58
            }
        }

        var minAmplitude: CGFloat {
            switch self {
            case .basementDive: return 16
            case .cornerChaos: return 20
            default: return 18
            }
        }

        var maxAmplitudeFactor: CGFloat {
            switch self {
            case .cornerChaos: return 0.082
            default: return 0.074
            }
        }

        var distanceAmplitudeFactor: CGFloat {
            switch self {
            case .basementDive: return 0.085
            case .cornerChaos: return 0.105
            default: return 0.095
            }
        }

        var allowsLoop: Bool {
            self != .basementDive
        }

        var minAlongOffset: CGFloat {
            4
        }

        var maxAlongOffset: CGFloat {
            switch self {
            case .cornerChaos: return 14
            default: return 11
            }
        }

        var alongOffsetFactor: CGFloat {
            switch self {
            case .basementDive: return 0.016
            case .cornerChaos: return 0.024
            default: return 0.019
            }
        }
    }
}

struct AppStorePhoneCanvas<Content: View>: View {
    @Environment(\.appScreenshotEnvironment) private var environment

    let seed: Int
    let titleLines: [String]
    let phoneOffsetY: CGFloat
    let phoneColorScheme: ColorScheme
    let content: Content

    @State private var textRect: CGRect = .zero

    init(
        seed: Int,
        titleLines: [String],
        phoneOffsetY: CGFloat,
        phoneColorScheme: ColorScheme,
        @ViewBuilder content: () -> Content
    ) {
        self.seed = seed
        self.titleLines = titleLines
        self.phoneOffsetY = phoneOffsetY
        self.phoneColorScheme = phoneColorScheme
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let wiggleSeed = seed ^ Int.random(in: 1...Int.max)
            let phoneScale: CGFloat = 0.93
            let phoneSize = CGSize(
                width: environment.screenshotSize.width * phoneScale,
                height: environment.screenshotSize.height * phoneScale
            )
            let phoneRect = CGRect(
                x: (proxy.size.width - phoneSize.width) / 2,
                y: (proxy.size.height - phoneSize.height) / 2 + phoneOffsetY,
                width: phoneSize.width,
                height: phoneSize.height
            )

            ZStack {
                Rectangle()
                    .fill(.accent)

                NeonWiggleRoute(
                    seed: wiggleSeed,
                    canvasSize: proxy.size,
                    textSafeRect: textRect,
                    deviceRect: phoneRect,
                    showsLine: true,
                    showsMarkers: false
                )

                NeonWiggleRoute(
                    seed: wiggleSeed,
                    canvasSize: proxy.size,
                    textSafeRect: textRect,
                    deviceRect: phoneRect,
                    showsLine: false,
                    showsMarkers: true
                )

                DeviceView {
                    content
                        .preferredColorScheme(phoneColorScheme)
                }
                .statusBarShown()
                .frame(width: phoneSize.width, height: phoneSize.height)
                .offset(y: phoneOffsetY)

                VStack(alignment: .leading, spacing: -22) {
                    ForEach(Array(titleLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
                .font(.system(size: 160, weight: .bold))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { textProxy in
                        Color.clear.preference(
                            key: ScreenshotTextBoundsKey.self,
                            value: textProxy.frame(in: .named("AppStorePhoneCanvas"))
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 56)
                .padding(.leading, 56)
                .padding(.trailing, 120)
            }
            .coordinateSpace(name: "AppStorePhoneCanvas")
            .onPreferenceChange(ScreenshotTextBoundsKey.self) { textRect = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum ScreenshotSampleData {
    private static let screenshotReferenceMonth = 1
    private static let screenshotReferenceYear = 2026
    private static let liveBundle: ScreenshotFakeDataBundle? = loadLiveBundle()
    private static let liveRunEditsByID: [UUID: RunEdit] = {
        guard let liveBundle else { return [:] }
        return Dictionary(uniqueKeysWithValues: liveBundle.runEdits.map { ($0.id, $0) })
    }()
    private static let liveStatisticsCache: [RunStatistic]? = makeLiveStatistics()

    static func shiftedLocations(
        from startDate: Date,
        limit: Int = 420,
        speedMultiplier: Double = 1.0
    ) -> [LocationData] {
        let baseLocations = Array((decodeLocationSampleData() ?? Constants.locationSampleData).prefix(limit))
        guard let firstTimestamp = baseLocations.first?.timestamp else { return baseLocations }

        return baseLocations.enumerated().map { index, location in
            var shifted = location
            let delta = location.timestamp.timeIntervalSince(firstTimestamp)
            shifted.timestamp = startDate.addingTimeInterval(delta)
            shifted.speed = max((location.speed ?? 0) * speedMultiplier, 0)
            shifted.latitude += Double(index) * 0.000006
            shifted.longitude += Double(index) * 0.000004
            return shifted
        }
    }

    static func statistic(
        id: UUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        name: String,
        startDate: Date,
        locationString: String,
        runTime: Double,
        distance: Double,
        topSpeed: Double,
        averageSpeed: Double,
        tags: [String],
        workoutType: WorkoutType,
        speedMultiplier: Double = 1.0,
        withAngles: Bool = false,
        locationLimit: Int = 420
    ) -> RunStatistic {
        let normalizedStartDate = shiftedToReferenceYear(startDate)
        let locations = shiftedLocations(from: normalizedStartDate, limit: locationLimit, speedMultiplier: speedMultiplier)
        var statistic = RunStatistic(
            id: id,
            runName: name,
            crewStatistics: [],
            runTime: runTime,
            runDistance: distance,
            topSpeed: topSpeed,
            averageSpeed: averageSpeed,
            kCalories: 1006,
            locationData: locations,
            tags: tags,
            workoutType: workoutType,
            startDate: normalizedStartDate,
            endDate: locations.last?.timestamp ?? normalizedStartDate.addingTimeInterval(runTime * 60),
            topSpeed1s: topSpeed + 1.4,
            topSpeed10s: topSpeed - 4.2,
            popUps: 7,
            percentageOnFoil: 88.7,
            turnsCount: 808
        )
        statistic.averageHeartRate = 131
        statistic.locationString = normalizedLocationString(locationString)
        statistic.startLocation = locations.first
        statistic.longestDistanceOnFoil = 1280
        statistic.angles = withAngles ? sampleAngles(from: locations) : []
        return statistic
    }

    static func angleStatistic() -> RunStatistic {
        bestAngleStatistic() ?? featuredStatistic(id: liveBundle?.featured.angleRunID) ?? statistic(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID(),
            name: "Angle Run",
            startDate: date(year: 2025, month: 1, day: 28, hour: 17, minute: 55),
            locationString: "Hyeres",
            runTime: 67,
            distance: 19840,
            topSpeed: 28.4,
            averageSpeed: 17.1,
            tags: ["#angle", "#mistral"],
            workoutType: .windsurf,
            speedMultiplier: 1.06,
            withAngles: true
        )
    }

    static func exportStatistic() -> RunStatistic {
        parawingDownwindRun()
    }

    static func listStatistics() -> [RunStatistic] {
        if let liveStatisticsCache {
            return liveStatisticsCache
        }

        func fallbackStatistic(
            id: String,
            name: String,
            day: Int,
            hour: Int,
            minute: Int,
            location: String,
            runTime: Double,
            distance: Double,
            topSpeed: Double,
            averageSpeed: Double,
            tags: [String],
            workoutType: WorkoutType,
            speedMultiplier: Double
        ) -> RunStatistic {
            statistic(
                id: UUID(uuidString: id) ?? UUID(),
                name: name,
                startDate: date(year: 2025, month: 1, day: day, hour: hour, minute: minute),
                locationString: location,
                runTime: runTime,
                distance: distance,
                topSpeed: topSpeed,
                averageSpeed: averageSpeed,
                tags: tags,
                workoutType: workoutType,
                speedMultiplier: speedMultiplier
            )
        }

        return [
            fallbackStatistic(
                id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
                name: "DW Parawing",
                day: 28,
                hour: 15,
                minute: 10,
                location: "Neuenburg → St-Blaise",
                runTime: 22.83,
                distance: 5320,
                topSpeed: 24,
                averageSpeed: 14,
                tags: ["#5.1brm", "#ml65", "#850S"],
                workoutType: .dWParawing,
                speedMultiplier: 0.78
            ),
            fallbackStatistic(
                id: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD",
                name: "DW SUP Foil",
                day: 28,
                hour: 12,
                minute: 46,
                location: "Concise → St-Blaise",
                runTime: 107,
                distance: 30930,
                topSpeed: 29,
                averageSpeed: 17,
                tags: ["#850S", "#105dw"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 1.02
            ),
            fallbackStatistic(
                id: "ABABABAB-1111-1111-1111-111111111111",
                name: "Foil Surf",
                day: 26,
                hour: 14,
                minute: 24,
                location: "Chez-le-Bart",
                runTime: 61,
                distance: 11840,
                topSpeed: 23.4,
                averageSpeed: 11.6,
                tags: ["#980S", "#ml47"],
                workoutType: .foilSurf,
                speedMultiplier: 0.86
            ),
            fallbackStatistic(
                id: "ABABABAB-2222-2222-2222-222222222222",
                name: "DW Parawing",
                day: 24,
                hour: 11,
                minute: 18,
                location: "Concise → St-Blaise",
                runTime: 100,
                distance: 32930,
                topSpeed: 31.3,
                averageSpeed: 17.5,
                tags: ["#5.1brm", "#850S"],
                workoutType: .dWParawing,
                speedMultiplier: 0.98
            ),
            fallbackStatistic(
                id: "ABABABAB-3333-3333-3333-333333333333",
                name: "Parawing",
                day: 21,
                hour: 13,
                minute: 2,
                location: "Saint-Aubin-Sauges",
                runTime: 88,
                distance: 16240,
                topSpeed: 20.1,
                averageSpeed: 11.1,
                tags: ["#4.5ensis", "#720S"],
                workoutType: .parawing,
                speedMultiplier: 0.74
            ),
            fallbackStatistic(
                id: "ABABABAB-4444-4444-4444-444444444444",
                name: "DW SUP",
                day: 18,
                hour: 12,
                minute: 11,
                location: "Neuenburg -> Concise",
                runTime: 96,
                distance: 22130,
                topSpeed: 19.8,
                averageSpeed: 13.9,
                tags: ["#105dw", "#1300S"],
                workoutType: .downwindSUP,
                speedMultiplier: 0.82
            ),
            fallbackStatistic(
                id: "ABABABAB-5555-5555-5555-555555555555",
                name: "DW SUP Foil",
                day: 17,
                hour: 10,
                minute: 48,
                location: "Neuenburg → St-Blaise",
                runTime: 20.25,
                distance: 5840,
                topSpeed: 32.2,
                averageSpeed: 17.4,
                tags: ["#850S", "#105dw"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 1.01
            ),
            fallbackStatistic(
                id: "ABABABAB-6666-6666-6666-666666666666",
                name: "Parawing",
                day: 14,
                hour: 15,
                minute: 36,
                location: "Saint-Aubin-Sauges",
                runTime: 72,
                distance: 13590,
                topSpeed: 18.7,
                averageSpeed: 10.8,
                tags: ["#4.5ensis", "#720S"],
                workoutType: .parawing,
                speedMultiplier: 0.7
            ),
            fallbackStatistic(
                id: "ABABABAB-7777-7777-7777-777777777777",
                name: "Foil Surf",
                day: 12,
                hour: 9,
                minute: 54,
                location: "Neuenburg",
                runTime: 54,
                distance: 9630,
                topSpeed: 21.9,
                averageSpeed: 10.7,
                tags: ["#foil", "#980S"],
                workoutType: .foilSurf,
                speedMultiplier: 0.83
            ),
            fallbackStatistic(
                id: "ABABABAB-8888-8888-8888-888888888888",
                name: "DW SUP Foil",
                day: 9,
                hour: 12,
                minute: 27,
                location: "Concise → St-Blaise",
                runTime: 109,
                distance: 31520,
                topSpeed: 30.6,
                averageSpeed: 17.3,
                tags: ["#850S", "#770R"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 1.0
            ),
            fallbackStatistic(
                id: "ABABABAB-9999-9999-9999-999999999999",
                name: "Parawing",
                day: 5,
                hour: 11,
                minute: 41,
                location: "Saint-Aubin-Sauges",
                runTime: 83,
                distance: 14910,
                topSpeed: 19.2,
                averageSpeed: 10.9,
                tags: ["#4.7frigate", "#700R"],
                workoutType: .parawing,
                speedMultiplier: 0.73
            ),
            fallbackStatistic(
                id: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE",
                name: "DW Parawing",
                day: 2,
                hour: 12,
                minute: 7,
                location: "Saint-Aubin-Sauges → St-Blaise",
                runTime: 164,
                distance: 9470,
                topSpeed: 9.1,
                averageSpeed: 3.5,
                tags: ["#850S", "#65ML"],
                workoutType: .dWParawing,
                speedMultiplier: 1.2
            ),
            statistic(
                id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") ?? UUID(),
                name: "DW SUP Foil",
                startDate: date(year: 2024, month: 12, day: 7, hour: 12, minute: 50),
                locationString: "Saint-Aubin-Sauges → St-Blaise",
                runTime: 85,
                distance: 23930,
                topSpeed: 30,
                averageSpeed: 17,
                tags: ["#850S"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 0.94
            ),
            statistic(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999999") ?? UUID(),
                name: "DW SUP Foil",
                startDate: date(year: 2024, month: 11, day: 19, hour: 12, minute: 47),
                locationString: "Saint-Aubin-Sauges → St-Blaise",
                runTime: 79,
                distance: 23930,
                topSpeed: 31,
                averageSpeed: 18,
                tags: ["#770R"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 0.96
            )
        ]
        .sorted(by: { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) })
    }

    static func importRun(from statistic: RunStatistic) -> ImportRun {
        let totalPoints = statistic.locationData.count
        let smoothedSpeeds = statistic.locationData.map { $0.speed ?? 3.0 }.smoothed(window: 120)
        let heartRates = statistic.locationData.enumerated().compactMap { index, location -> HeartRate? in
            guard index.isMultiple(of: 18) else { return nil }
            let progress = Double(index) / Double(max(totalPoints - 1, 1))
            let speedFactor = min(max(smoothedSpeeds[index] / 9.0, 0.0), 1.0)
            let baseline = 65.0 + progress * 12.0
            let bpm = baseline + speedFactor * 45.0 + Double.random(in: -1.5...1.5)
            return HeartRate(date: location.timestamp, heartRate: max(60, min(125, bpm)))
        }

        return ImportRun(
            id: statistic.id,
            runTime: statistic.runTime,
            topSpeed: statistic.topSpeed,
            averageSpeed: statistic.averageSpeed ?? 0,
            totalDistance: statistic.runDistance,
            startLocation: statistic.startLocation,
            locations: statistic.locationData,
            heartRates: heartRates,
            averageHeartRate: statistic.averageHeartRate ?? 0,
            workoutType: statistic.workoutType,
            tags: statistic.tags ?? [],
            locationString: statistic.locationString
        )
    }

    static func makeDownwindManager() -> DownwindManager {
        let manager = DownwindManager()
        let stats = listStatistics()
        manager.forcePremiumForScreenshots = true
        manager.hasPurchasedPremium = true
        manager.editCounter = 0
        manager.showUpgradeSheet = false
        manager.lastVersionNewsClosed = manager.currentAppVersion
        manager.appOpened = 0
        manager.user.name = "Nils Mango"
        manager.runStatistics = stats
        manager.statisticsCount = stats.count
        manager.importedRuns = liveBundle?.importRuns ?? stats.map(importRun(from:))
        manager.runEdits = liveBundle?.runEdits ?? stats.compactMap(makeRunEditFallback(from:))
        manager.tags = sortedScreenshotTags(uniqueStrings(stats.flatMap { $0.tags ?? [] }))
        manager.locationStrings = uniqueStrings(stats.compactMap(\.locationString))
        manager.workoutUsageCount = Dictionary(grouping: stats.compactMap(\.workoutType), by: { $0 }).mapValues(\.count)
        manager.updateGroupedRunArraySync()
        return manager
    }

    static func makeHomeManager(
        showTracker: Bool = true,
        workoutType: WorkoutType = .downwindSUPFoil,
        includeImportedRuns: Bool = false
    ) -> DownwindManager {
        let manager = makeDownwindManager()
        manager.showTracker = showTracker
        manager.hasHealthActivated = true
        manager.workoutType = workoutType
        if !includeImportedRuns {
            manager.showGPXImport = false
        }
        return manager
    }

    static func makeDashboardManager() -> TrackedElementsManager {
        let manager = TrackedElementsManager()
        manager.showWidgetTap = false
        let updated = Date().addingTimeInterval(-120)

        if let liveBundle {
            manager.dashboards = normalizedDashboards(liveBundle.dashboards, updated: updated)
            manager.widgetDashboardIds = liveBundle.widgetDashboardIds
            return manager
        }

        let bielerseeURL = "https://wind.example/bielersee"
        let neuchURL = "https://wind.example/neuchatel"

        manager.dashboards = normalizedDashboards([
            Dashboard(
                name: "Bielersee",
                elements: [
                    trackedElement(url: bielerseeURL, label: "Wingreis Avg", value: "1.7 kn", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Wingreis Gust", value: "3.3 kn", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Wingreis Dir", value: "O", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Vingelz Avg", value: "1.0 kn", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Vingelz Gust", value: "2.2 kn", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Vingelz Dir", value: "SSW", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Hafen Avg", value: "2.5 kn", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Hafen Gust", value: "4.1 kn", updated: updated),
                    trackedElement(url: bielerseeURL, label: "Hafen Dir", value: "NW", updated: updated)
                ]
            ),
            Dashboard(
                name: "Lac de Neuchâtel",
                elements: [
                    trackedElement(url: neuchURL, label: "Yverdon Avg", value: "18.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yverdon Gust", value: "20.5 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yverdon Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Avg", value: "15.4 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Gust", value: "19.1 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Avg", value: "13.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Gust", value: "21.2 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Avg", value: "7.8 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Gust", value: "13.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Neuch Avg", value: "11.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Neuch Gust", value: "16.7 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Neuch Dir", value: "ENE", updated: updated)
                ]
            )
        ], updated: updated)
        manager.widgetDashboardIds = manager.dashboards.map(\.id)
        return manager
    }

    static func homeStatistic() -> RunStatistic {
        bestHomeStatistic() ?? featuredStatistic(id: liveBundle?.featured.homeRunID) ?? statistic(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212") ?? UUID(),
            name: "Home Session",
            startDate: date(year: 2025, month: 4, day: 1, hour: 11, minute: 22),
            locationString: "Neuenburg -> St-Blaise",
            runTime: 85,
            distance: 28150,
            topSpeed: 35,
            averageSpeed: 20,
            tags: ["#105dw", "#1130S", "#1300S", "#2.9kaa", "#3.6kaa", "#4.5ensis", "#770R", "#850S", "#860R", "#980S", "#p140", "#tp170"],
            workoutType: .downwindSUP,
            speedMultiplier: 1.08
        )
    }

    static func mapStatistic() -> RunStatistic {
        longestDownwindStatistic() ?? bestMapStatistic() ?? featuredStatistic(id: liveBundle?.featured.mapRunID) ?? statistic(
            id: UUID(uuidString: "23232323-2323-2323-2323-232323232323") ?? UUID(),
            name: "Simple Route",
            startDate: date(year: 2025, month: 4, day: 1, hour: 12, minute: 48),
            locationString: "Cortaillod -> Yverdon-les-Bains",
            runTime: 118,
            distance: 36320,
            topSpeed: 34,
            averageSpeed: 18.5,
            tags: ["#simple", "#map", "#long"],
            workoutType: .downwindSUPFoil,
            speedMultiplier: 1.04,
            locationLimit: 620
        )
    }

    static func editStatistic() -> RunStatistic {
        longestDownwindStatistic()
        ?? bestDetailStatistic()
        ?? mapStatistic()
    }

    static func detailStatistic() -> RunStatistic {
        featuredStatistic(id: liveBundle?.featured.statsDetailRunID) ?? bestDetailStatistic() ?? statistic(
            id: UUID(uuidString: "34343434-3434-3434-3434-343434343434") ?? UUID(),
            name: "DW Parawing",
            startDate: date(year: 2025, month: 4, day: 1, hour: 15, minute: 21),
            locationString: "Cortaillod -> Yverdon-les-Bains",
            runTime: 85,
            distance: 28150,
            topSpeed: 35,
            averageSpeed: 20,
            tags: ["#dw", "#parawing"],
            workoutType: .dWParawing,
            speedMultiplier: 1.08
        )
    }

    static func gpxImportRuns() -> [ImportRun] {
        if let queued = liveBundle?.queuedImportRuns, !queued.isEmpty {
            return queued
        }

        return [
            ImportRun(
                id: UUID(uuidString: "45454545-4545-4545-4545-454545454545") ?? UUID(),
                runTime: 85,
                topSpeed: 35,
                averageSpeed: 20,
                totalDistance: 28150,
                startLocation: shiftedLocations(from: date(year: 2025, month: 4, day: 1, hour: 15, minute: 22), limit: 300).first,
                locations: shiftedLocations(from: date(year: 2025, month: 4, day: 1, hour: 15, minute: 22), limit: 300),
                heartRates: [],
                averageHeartRate: 0,
                workoutType: nil,
                tags: [],
                locationString: "Cortaillod -> Yverdon-les-Bains"
            ),
            ImportRun(
                id: UUID(uuidString: "56565656-5656-5656-5656-565656565656") ?? UUID(),
                runTime: 118,
                topSpeed: 34,
                averageSpeed: 18.5,
                totalDistance: 36320,
                startLocation: shiftedLocations(from: date(year: 2025, month: 4, day: 1, hour: 12, minute: 48), limit: 360).first,
                locations: shiftedLocations(from: date(year: 2025, month: 4, day: 1, hour: 12, minute: 48), limit: 360),
                heartRates: [],
                averageHeartRate: 0,
                workoutType: nil,
                tags: [],
                locationString: "Neuenburg -> St-Blaise"
            )
        ]
    }

    static func highlightedTags() -> [String] {
        if let preferred = preferredHighlightedTag(from: listStatistics().flatMap { $0.tags ?? [] }) {
            return [preferred]
        }
        return ["#850S"]
    }

    static func highlightedPlaces() -> [String] {
        let places = preferredHighlightedPlaces(from: listStatistics().compactMap(\.locationString))
        if !places.isEmpty {
            return Array(places.prefix(2))
        }
        return ["Saint-Aubin-Sauges → St-Blaise", "Only sessions with angles"]
    }

    private static func loadLiveBundle() -> ScreenshotFakeDataBundle? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let bundles = [Bundle.main, Bundle(for: ScreenshotBundleLocator.self)]
        let bundledCandidateURLs = bundles.flatMap { bundle in
            [
                bundle.url(forResource: "AppStoreScreenshotData-2025", withExtension: "json"),
                bundle.url(forResource: "AppStoreScreenshotData", withExtension: "json")
            ]
        }.compactMap { $0 }
        let unbundledCandidateURLs = unbundledCandidateURLs(in: sourceDirectory)
        let candidateURLs = unbundledCandidateURLs + bundledCandidateURLs

        for url in candidateURLs where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let bundle = try? decoder.decode(ScreenshotFakeDataBundle.self, from: data) {
                return normalized(bundle: bundle)
            }
        }

        return nil
    }

    private static func unbundledCandidateURLs(in sourceDirectory: URL) -> [URL] {
        return [
            sourceDirectory.appendingPathComponent(".screenshot-data/AppStoreScreenshotData.json"),
            sourceDirectory.appendingPathComponent(".screenshot-data/AppStoreScreenshotData-2025.json"),
            sourceDirectory.appendingPathComponent(".AppStoreScreenshotData.json"),
            sourceDirectory.appendingPathComponent(".AppStoreScreenshotData-2025.json"),
            sourceDirectory.appendingPathComponent("AppStoreScreenshotData.json"),
            sourceDirectory.appendingPathComponent("AppStoreScreenshotData-2025.json")
        ]
    }

    private static var shouldLoadUnbundledFixture: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["SCREENSHOT_SAMPLE_DATA_SOURCE"] == "filesystem"
            || processInfo.arguments.contains("--screenshot-sample-data-filesystem")
    }

    private static func makeLiveStatistics() -> [RunStatistic]? {
        guard let liveBundle else { return nil }

        return liveBundle.importRuns
            .map { run in
                statistic(from: run, edit: liveRunEditsByID[run.id])
            }
            .sorted(by: { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) })
    }

    private static func featuredStatistic(id: UUID?) -> RunStatistic? {
        guard let id else { return nil }
        return listStatistics().first(where: { $0.id == id })
    }

    private static func bestAngleStatistic() -> RunStatistic? {
        let preferredTypes: [WorkoutType] = [.parawing, .dWParawing, .paraUpDown, .windsurf, .windFoil, .wingFoil]
        for preferredType in preferredTypes {
            let matches = listStatistics().filter { ($0.workoutType ?? .surf) == preferredType }
            if let best = matches.max(by: { angleStatisticScore($0) < angleStatisticScore($1) }) {
                return statisticEnsuringAngles(best)
            }
        }

        if let best = listStatistics()
            .filter({ ($0.workoutType ?? .surf).angleSport })
            .max(by: { angleStatisticScore($0) < angleStatisticScore($1) }) {
            return statisticEnsuringAngles(best)
        }

        return nil
    }

    private static func bestExportStatistic() -> RunStatistic? {
        listStatistics()
            .filter { ($0.workoutType ?? .surf).isDWSport }
            .max(by: { exportStatisticScore($0) < exportStatisticScore($1) })
    }

    private static func bestHomeStatistic() -> RunStatistic? {
        bestDetailStatistic() ?? bestExportStatistic() ?? listStatistics().first
    }

    private static func bestMapStatistic() -> RunStatistic? {
        if let routePlace = preferredHighlightedPlaces(from: listStatistics().compactMap(\.locationString)).first,
           let match = listStatistics()
            .filter({ $0.locationString == routePlace })
            .max(by: { exportStatisticScore($0) < exportStatisticScore($1) }) {
            return match
        }
        return bestExportStatistic() ?? bestDetailStatistic()
    }

    private static func bestDetailStatistic() -> RunStatistic? {
        let preferred = listStatistics()
            .filter {
                ($0.workoutType ?? .surf) == .dWParawing &&
                $0.runDistance >= 20_000 &&
                ($0.averageSpeed ?? 0) >= 19 &&
                ($0.tags ?? []).contains(where: { $0.caseInsensitiveCompare("#720s") == .orderedSame })
            }
            .max(by: { detailStatisticScore($0) < detailStatisticScore($1) })

        if let preferred {
            return preferred
        }

        return listStatistics()
            .filter {
                ($0.workoutType ?? .surf) == .dWParawing &&
                $0.runDistance >= 20_000
            }
            .max(by: { detailStatisticScore($0) < detailStatisticScore($1) })
            ?? listStatistics()
            .filter {
                ($0.workoutType ?? .surf).isDWSport &&
                $0.runDistance >= 20_000
            }
            .max(by: { detailStatisticScore($0) < detailStatisticScore($1) })
    }

    private static func statisticEnsuringAngles(_ statistic: RunStatistic) -> RunStatistic {
        guard statistic.angles?.isEmpty ?? true else { return statistic }
        var enriched = statistic
        enriched.angles = sampleAngles(from: statistic.locationData)
        return enriched
    }

    private static func angleStatisticScore(_ statistic: RunStatistic) -> Double {
        let typeBonus: Double
        switch statistic.workoutType ?? .surf {
        case .parawing: typeBonus = 180
        case .dWParawing: typeBonus = 150
        case .paraUpDown: typeBonus = 120
        case .windsurf: typeBonus = 90
        default: typeBonus = 0
        }

        let tagBonus = (statistic.tags ?? []).contains { $0.localizedCaseInsensitiveContains("720") || $0.localizedCaseInsensitiveContains("angle") } ? 45.0 : 0.0
        let averageSpeed = statistic.averageSpeed ?? 0
        let distanceScore = statistic.runDistance / 1000
        return typeBonus + tagBonus + averageSpeed + distanceScore
    }

    private static func detailStatisticScore(_ statistic: RunStatistic) -> Double {
        let typeBonus = (statistic.workoutType ?? .surf) == .dWParawing ? 100.0 : 0.0
        let tagBonus = (statistic.tags ?? []).contains(where: { $0.caseInsensitiveCompare("#720s") == .orderedSame }) ? 60.0 : 0.0
        let heartRateBonus = (statistic.averageHeartRate ?? 0) > 0 ? 40.0 : 0.0
        let averageSpeed = statistic.averageSpeed ?? 0
        let distanceScore = statistic.runDistance / 1000
        return typeBonus + tagBonus + heartRateBonus + averageSpeed * 8 + distanceScore
    }

    private static func exportStatisticScore(_ statistic: RunStatistic) -> Double {
        let heartRateBonus = (statistic.averageHeartRate ?? 0) > 0 ? 25.0 : 0.0
        let averageSpeed = statistic.averageSpeed ?? 0
        let distanceScore = statistic.runDistance / 1000
        return heartRateBonus + averageSpeed * 6 + distanceScore
    }

    private static func statistic(from run: ImportRun, edit: RunEdit?) -> RunStatistic {
        let workoutType = edit?.newWorkoutType ?? run.workoutType ?? .surf
        let distance = edit?.newTotalDistance ?? run.totalDistance
        let totalTime = edit?.newTotalTime ?? run.runTime
        let averageSpeed = edit?.newAverageSpeed ?? run.averageSpeed
        let topSpeed = edit?.newTopSpeed ?? run.topSpeed
        let startDate = shiftedToReferenceYear(run.startLocation?.timestamp ?? run.locations.first?.timestamp ?? .now)
        let endDate = run.locations.last?.timestamp ?? startDate.addingTimeInterval(totalTime * 60)
        let calories = max(distance / 28, 320)
        let tags = edit?.newTags ?? run.tags

        var statistic = RunStatistic(
            id: run.id,
            runName: workoutType.prettyString,
            crewStatistics: [],
            runTime: totalTime,
            runDistance: distance,
            topSpeed: topSpeed,
            averageSpeed: averageSpeed,
            kCalories: calories,
            locationData: run.locations,
            tags: tags,
            workoutType: workoutType,
            startDate: startDate,
            endDate: endDate,
            topSpeed1s: edit?.topSpeed1s ?? (topSpeed + 1.4),
            topSpeed10s: edit?.topSpeed10s ?? max(averageSpeed + 1.3, topSpeed - 4.2),
            popUps: edit?.popUps ?? (workoutType.calculateFoilingStats ? 7 : 0),
            percentageOnFoil: edit?.percentageOnFoil ?? (workoutType.calculateFoilingStats ? 88.7 : 0),
            turnsCount: edit?.turnsCount ?? (workoutType.countTurns ? 34 : 0)
        )
        statistic.averageHeartRate = run.averageHeartRate > 0 ? run.averageHeartRate : nil
        statistic.locationString = normalizedLocationString(edit?.locationString ?? run.locationString)
        statistic.startLocation = edit?.startLocation ?? run.startLocation ?? run.locations.first
        statistic.longestDistanceOnFoil = edit?.longestDistanceOnFoil
        statistic.angles = edit?.angles ?? []
        statistic.waves = edit?.waves
        return statistic
    }

    private static func makeRunEditFallback(from statistic: RunStatistic) -> RunEdit? {
        guard let workoutType = statistic.workoutType else { return nil }

        return RunEdit(
            id: statistic.id,
            startLocation: statistic.startLocation,
            finishLocation: statistic.locationData.last,
            deletedLocations: nil,
            newTotalTime: statistic.runTime,
            newTotalDistance: statistic.runDistance,
            newTopSpeed: statistic.topSpeed,
            topSpeed10s: statistic.topSpeed10s,
            topSpeed1s: statistic.topSpeed1s,
            newAverageSpeed: statistic.averageSpeed,
            popUps: statistic.popUps,
            percentageOnFoil: statistic.percentageOnFoil,
            turnsCount: statistic.turnsCount,
            longestDistanceOnFoil: statistic.longestDistanceOnFoil,
            waves: statistic.waves,
            newTags: statistic.tags,
            newWorkoutType: workoutType,
            locationString: statistic.locationString,
            angles: statistic.angles
        )
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func frequentValues(from values: [String]) -> [String] {
        let counts = values.reduce(into: [String: Int]()) { partialResult, value in
            partialResult[value, default: 0] += 1
        }

        return counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs, default: 0]
            let rhsCount = counts[rhs, default: 0]
            if lhsCount == rhsCount {
                return lhs < rhs
            }
            return lhsCount > rhsCount
        }
    }

    private static func preferredHighlightedTag(from values: [String]) -> String? {
        let frequentTags = frequentValues(from: values)
        let preferredOrder = ["#850S", "#720s", "#82ml", "#1300S", "#980S", "#1130S", "#105dw", "#65ML"]
        for preferred in preferredOrder {
            if let match = frequentTags.first(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
                return match
            }
        }
        return frequentTags.first
    }

    private static func preferredHighlightedPlaces(from values: [String]) -> [String] {
        let routePlaces = values.filter { $0.contains("→") || $0.contains("->") }
        let frequentRoutePlaces = frequentValues(from: routePlaces)
        if !frequentRoutePlaces.isEmpty {
            return frequentRoutePlaces
        }
        return frequentValues(from: values)
    }

    private static func sortedScreenshotTags(_ values: [String]) -> [String] {
        values.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func sampleAngles(from locations: [LocationData]) -> [MapAngle] {
        guard locations.count > 310 else { return [] }

        return [
            MapAngle(coordinates: [
                coordinate(from: locations[60]),
                coordinate(from: locations[120]),
                coordinate(from: locations[180])
            ]),
            MapAngle(coordinates: [
                coordinate(from: locations[160]),
                coordinate(from: locations[235]),
                coordinate(from: locations[300])
            ])
        ]
    }

    private static func coordinate(from location: LocationData) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    private static func trackedElement(url: String, label: String, value: String, updated: Date) -> TrackedElement {
        TrackedElement(url: url, xpath: "//value", userLabel: label, lastValue: value, lastUpdated: updated, lastError: nil)
    }

    private static func longestDownwindStatistic() -> RunStatistic? {
        listStatistics()
            .filter { ($0.workoutType ?? .surf).isDWSport }
            .max(by: {
                if $0.runDistance == $1.runDistance {
                    return ($0.averageSpeed ?? 0) < ($1.averageSpeed ?? 0)
                }
                return $0.runDistance < $1.runDistance
            })
    }

    private static func normalizedDashboards(_ dashboards: [Dashboard], updated: Date) -> [Dashboard] {
        dashboards.map { dashboard in
            if dashboard.name == "Bielersee" {
                return dashboard
            }

            let lowercasedName = dashboard.name.lowercased()
            guard lowercasedName.contains("neuch") else {
                return dashboard
            }

            let neuchURL = dashboard.elements.first?.url ?? "https://wind.example/neuchatel"
            return Dashboard(
                id: dashboard.id,
                name: "Lac de Neuchâtel",
                elements: [
                    trackedElement(url: neuchURL, label: "Yverdon Avg", value: "18.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yverdon Gust", value: "20.5 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yverdon Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Avg", value: "15.4 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Gust", value: "19.1 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Avg", value: "13.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Gust", value: "21.2 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Avg", value: "7.8 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Gust", value: "13.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Neuch Avg", value: "11.9 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Neuch Gust", value: "16.7 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Neuch Dir", value: "ENE", updated: updated)
                ]
            )
        }
    }

    private static func normalized(bundle: ScreenshotFakeDataBundle) -> ScreenshotFakeDataBundle {
        var normalized = bundle
        normalized.sourceYear = screenshotReferenceYear
        normalized.exportedAt = shiftedToReferenceYear(bundle.exportedAt)
        normalized.importRuns = bundle.importRuns.map(normalizedImportRun(_:))
        normalized.queuedImportRuns = bundle.queuedImportRuns.map(normalizedImportRun(_:))
        normalized.runEdits = bundle.runEdits.map(normalizedRunEdit(_:))
        normalized.featured.highlightedPlaces = bundle.featured.highlightedPlaces.map { normalizedLocationString($0) ?? $0 }
        return normalized
    }

    private static func normalizedImportRun(_ run: ImportRun) -> ImportRun {
        ImportRun(
            id: run.id,
            runTime: run.runTime,
            topSpeed: run.topSpeed,
            averageSpeed: run.averageSpeed,
            totalDistance: run.totalDistance,
            startLocation: run.startLocation.map(normalizedLocationData(_:)),
            locations: run.locations.map(normalizedLocationData(_:)),
            heartRates: run.heartRates.map(normalizedHeartRate(_:)),
            averageHeartRate: run.averageHeartRate,
            workoutType: run.workoutType,
            tags: run.tags,
            locationString: normalizedLocationString(run.locationString)
        )
    }

    private static func normalizedRunEdit(_ edit: RunEdit) -> RunEdit {
        var normalized = edit
        normalized.startLocation = edit.startLocation.map(normalizedLocationData(_:))
        normalized.finishLocation = edit.finishLocation.map(normalizedLocationData(_:))
        normalized.deletedLocations = edit.deletedLocations?.map(normalizedLocationData(_:))
        normalized.waves = edit.waves?.map { $0.map(normalizedLocationData(_:)) }
        normalized.locationString = normalizedLocationString(edit.locationString)
        return normalized
    }

    private static func normalizedLocationData(_ location: LocationData) -> LocationData {
        var normalized = location
        normalized.timestamp = shiftedToReferenceYear(location.timestamp)
        return normalized
    }

    private static func normalizedHeartRate(_ heartRate: HeartRate) -> HeartRate {
        HeartRate(date: shiftedToReferenceYear(heartRate.date), heartRate: heartRate.heartRate)
    }

    private static func normalizedLocationString(_ value: String?) -> String? {
        guard let value else { return nil }
        return value
            .replacingOccurrences(of: " -> ", with: " → ")
            .replacingOccurrences(of: "->", with: "→")
    }

    private static func shiftedToReferenceYear(_ date: Date) -> Date {
        var components = Calendar.current.dateComponents([.month, .day, .hour, .minute, .second, .nanosecond], from: date)
        components.year = screenshotReferenceYear
        components.month = screenshotReferenceMonth
        return Calendar.current.date(from: components) ?? date
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(
                year: screenshotReferenceYear,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .now
    }
}

struct ScreenshotDashboardHomeView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeHomeManager(showTracker: false)
    @StateObject private var manager = ScreenshotSampleData.makeDashboardManager()

    var body: some View {
        StartView(
            downwindManager: downwindManager,
            initialDashboardManager: manager,
            animateDashboardDirectionArrows: false
        )
    }
}

struct ScreenshotStatisticContainer<Content: View>: View {
    @ObservedObject var downwindManager: DownwindManager
    let statisticID: UUID
    let content: (Binding<RunStatistic>) -> Content

    init(
        downwindManager: DownwindManager,
        statisticID: UUID,
        @ViewBuilder content: @escaping (Binding<RunStatistic>) -> Content
    ) {
        self.downwindManager = downwindManager
        self.statisticID = statisticID
        self.content = content
    }

    var body: some View {
        if let index = downwindManager.runStatistics.firstIndex(where: { $0.id == statisticID }) {
            content($downwindManager.runStatistics[index])
        } else {
            Color(.systemGroupedBackground)
        }
    }
}

struct ScreenshotPlacesView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()
    @State private var path: [ScreenshotRoute] = [.places]

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .navigationDestination(for: ScreenshotRoute.self) { route in
                    switch route {
                    case .statisticsOverview:
                        StatisticsView(downwindManager: downwindManager)
                    case .places:
                        GroupedTagsListView(
                            downwindManager: downwindManager,
                            initialLocation: "Neuenburg → St-Blaise",
                            initialShowOnlyAngles: false,
                            initialTab: .locations
                        )
                    case .tags:
                        GroupedTagsListView(
                            downwindManager: downwindManager,
                            initialTags: ScreenshotSampleData.highlightedTags(),
                            initialTab: .tags
                        )
                    }
                }
        }
    }
}

struct ScreenshotTagsView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()
    @State private var path: [ScreenshotRoute] = [.tags]

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .navigationDestination(for: ScreenshotRoute.self) { route in
                    switch route {
                    case .statisticsOverview:
                        StatisticsView(downwindManager: downwindManager)
                    case .places:
                        GroupedTagsListView(
                            downwindManager: downwindManager,
                            initialLocation: "Neuenburg → St-Blaise",
                            initialShowOnlyAngles: false,
                            initialTab: .locations
                        )
                    case .tags:
                        GroupedTagsListView(
                            downwindManager: downwindManager,
                            initialTags: ScreenshotSampleData.highlightedTags(),
                            initialTab: .tags
                        )
                    }
                }
        }
    }
}

struct ScreenshotAngleToolView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        let statistic = ScreenshotSampleData.angleStatistic()

        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: statistic.id
            ) { statistic in
                WindSportStatisticsMap(
                    downwindManager: downwindManager,
                    statisticsData: statistic,
                    lineWidth: 6,
                    angleTool: true
                )
            }
            .navigationTitle(statistic.locationString ?? "Angle Tool")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ScreenshotHomeButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            if systemImage == "GPX" {
                Text("GPX")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ScreenshotTagChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.systemGray5), in: Capsule())
    }
}

private struct ScreenshotWatchOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.black)
                .frame(width: 176, height: 214)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 16)

            VStack(spacing: 10) {
                Text("11:27")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.green.opacity(0.18))
                    .overlay {
                        Label("Start", systemImage: "play")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .frame(height: 48)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.orange.opacity(0.18))
                    .overlay {
                        Text("DW SUP Foil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    .frame(height: 44)

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.28))
                        .overlay {
                            Text("2 #")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                        }

                    Circle()
                        .fill(Color.green.opacity(0.28))
                        .overlay {
                            Image(systemName: "location.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                        }
                }
                .frame(height: 38)
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct ScreenshotWorkoutPickerOverlay: View {
    private let options = [
        "Foil Surf",
        "SUP Foil",
        "DW SUP Foil",
        "DW SUP",
        "DW Prone Foil",
        "Wing Foil",
        "Parawing",
        "DW Parawing",
        "Wind Foil",
        "Kite Foil",
        "Kite",
        "Windsurf",
        "Pump Foil",
        "Wake Thief",
        "Wake Foil",
        "Wake Surf"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                HStack {
                    Text(option)
                        .foregroundStyle(.primary)
                    Spacer()
                    if option == "DW SUP Foil" {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)

                if index < options.count - 1 {
                    Divider()
                }
            }
        }
        .frame(width: 362)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
    }
}

private struct ScreenshotEditMenuOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            menuRow(title: "Set Start here", systemImage: "play.fill")
            Divider()
            menuRow(title: "Set Finish here", systemImage: "flag.checkered")
            Divider()
            menuRow(title: "Remove Point", systemImage: "trash")
        }
        .frame(width: 270)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private func menuRow(title: String, systemImage: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

private struct ScreenshotGPXImportCard: View {
    let run: ImportRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "calendar")
                Text(dateString)
                    .fontWeight(.bold)
                Spacer()
            }

            if let locationString = run.locationString {
                HStack(alignment: .top) {
                    Image(systemName: "location.fill")
                    Text(locationString)
                        .fontWeight(.bold)
                    Spacer()
                }
            }

            Text("Run Time: \(makePrettyTime(timeInMinutes: run.runTime))")
            Text("Total Distance: \(makePrettyDistance(meters: run.totalDistance, system: .metric, statistics: true))")
            Text("Number of locations found: \(run.locations.count.formatted())")

            Button("Set Activity Type") {
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Text("Tags: No Tags")

            Button("Add Tags") {
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dateString: String {
        let start = run.startLocation?.timestamp ?? run.locations.first?.timestamp ?? .now
        let end = run.locations.last?.timestamp ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(makeStringFromDate(start)) \(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct ScreenshotWatchSupportView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeHomeManager(
        showTracker: true,
        workoutType: .downwindSUP
    )
    @StateObject private var manager = ScreenshotSampleData.makeDashboardManager()

    var body: some View {
        StartView(
            downwindManager: downwindManager,
            initialDashboardManager: manager,
            animateDashboardDirectionArrows: false
        )
        .overlay(alignment: .bottom) {
            ScreenshotWatchOverlay()
                .offset(y: 12)
        }
    }
}

struct ScreenshotWaterSportsView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeHomeManager(
        showTracker: true,
        workoutType: .downwindSUPFoil
    )
    @StateObject private var manager = ScreenshotSampleData.makeDashboardManager()

    var body: some View {
        StartView(
            downwindManager: downwindManager,
            initialDashboardManager: manager,
            animateDashboardDirectionArrows: false
        )
        .overlay(alignment: .top) {
            ScreenshotWorkoutPickerOverlay()
                .padding(.top, 110)
        }
    }
}

struct ScreenshotStatisticsOverviewView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        NavigationStack {
            StatisticsView(downwindManager: downwindManager)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {} label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
        }
    }
}

private enum ScreenshotRoute: Hashable {
    case statisticsOverview
    case places
    case tags
}

struct ScreenshotEditRouteView: View {
    @StateObject private var downwindManager: DownwindManager = {
        let mgr = ScreenshotSampleData.makeDownwindManager()
        mgr.runStatistics.append(ScreenshotSampleData.parawingDownwindRun())
        return mgr
    }()

    var body: some View {
        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: ScreenshotSampleData.parawingDownwindRun().id
            ) { statistic in
                EditMap(downwindManager: downwindManager, statisticsData: statistic)
            }
            .navigationTitle("Edit Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                    }
                }
            }
        }
    }
}

struct ScreenshotSimpleMapView: View {
    @StateObject private var downwindManager: DownwindManager = {
        let mgr = ScreenshotSampleData.makeDownwindManager()
        let parawingRun = ScreenshotSampleData.parawingDownwindRun()
        mgr.runStatistics.append(parawingRun)
        mgr.importedRuns.append(ScreenshotSampleData.importRun(from: parawingRun))
        return mgr
    }()

    var body: some View {
        ScrollViewReader { proxy in
            NavigationStack {
                ScreenshotStatisticContainer(
                    downwindManager: downwindManager,
                    statisticID: ScreenshotSampleData.parawingDownwindRun().id
                ) { statistic in
                    StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic)
                }
                .navigationTitle(ScreenshotSampleData.parawingDownwindRun().locationString ?? "Map")
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                withAnimation {
                    proxy.scrollTo("measureAngles", anchor: .bottom)
                }
            }
//            .task {
//                try? await Task.sleep(for: .seconds(0.3))
//                proxy.scrollTo("measureAngles", anchor: .bottom)
//            }
        }
    }
}

struct ScreenshotStatsDetailView: View {
    @StateObject private var downwindManager: DownwindManager = {
        let mgr = ScreenshotSampleData.makeDownwindManager()
        let parawingRun = ScreenshotSampleData.parawingDownwindRun()
        mgr.runStatistics.append(parawingRun)
        mgr.importedRuns.append(ScreenshotSampleData.importRun(from: parawingRun))
        return mgr
    }()

    var body: some View {
        ScrollViewReader { proxy in
            NavigationStack {
                ScreenshotStatisticContainer(
                    downwindManager: downwindManager,
                    statisticID: ScreenshotSampleData.parawingDownwindRun().id
                ) { statistic in
                    StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic)
                }
            }
            .onAppear {
                withAnimation {
                    proxy.scrollTo("speedDistribution", anchor: .center)
                }
                
            }
//            .task {
//                try? await Task.sleep(for: .seconds(0.3))
//                proxy.scrollTo("speedDistribution", anchor: .center)
//            }
        }
    }
}

struct ScreenshotGPXImportView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeHomeManager(
        showTracker: false,
        workoutType: .downwindSUPFoil,
        includeImportedRuns: true
    )
    @StateObject private var manager = ScreenshotSampleData.makeDashboardManager()

    var body: some View {
        StartView(
            downwindManager: downwindManager,
            initialDashboardManager: manager,
            initialImportedRuns: ScreenshotSampleData.gpxImportRuns(),
            animateDashboardDirectionArrows: false
        )
    }
}

private struct ScreenshotTopBar: View {
    var showChart: Bool = true

    var body: some View {
        HStack {
            Text("Aloha Nils Mango!")
                .font(.title2.weight(.bold))
            Spacer()
            if showChart {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.accent)
            }
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundStyle(.accent)
        }
    }
}

private struct ScreenshotPrimaryNavigationRow: View {
    var includeGPX: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ScreenshotHomeButton(title: "Statistics", systemImage: "chart.xyaxis.line")
            ScreenshotHomeButton(title: "Dashboards", systemImage: "gauge.open.with.lines.needle.33percent")
            if includeGPX {
                ScreenshotHomeButton(title: "Import Runs", systemImage: "GPX")
            }
        }
    }
}

private struct ScreenshotDashboardWidgetCard: View {
    let dashboard: Dashboard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(dashboard.name)
                .font(.headline.weight(.semibold))

            VStack(spacing: 10) {
                ForEach(Array(dashboard.elements.prefix(4).enumerated()), id: \.offset) { _, element in
                    HStack {
                        Text(element.userLabel)
                            .fontWeight(.medium)
                        Spacer()
                        Text(element.lastValue ?? "--")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Text("Last updated 2 min ago")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ScreenshotRunDetailMockView: View {
    let statisticsData: RunStatistic
    let title: String
    var showsExportOverlay: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))

                    HStack(spacing: 10) {
                        Text(statisticsData.workoutType?.prettyString ?? "DW SUP Foil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())

                        Text(statisticsData.locationString ?? "Neuenburg → St-Blaise")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                ScreenshotMetricGrid(statistic: statisticsData)
                ScreenshotMapMockView(mode: .simple)
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.title3.weight(.bold))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(statisticsData.tags ?? [], id: \.self) { tag in
                            ScreenshotTagChip(title: tag)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Highlights")
                        .font(.title3.weight(.bold))

                    ScreenshotInfoRow(title: "Fastest 10 s", value: makePrettySpeed(speed: statisticsData.topSpeed10s, system: .metric))
                    ScreenshotInfoRow(title: "Longest glide", value: makePrettyDistance(meters: statisticsData.longestDistanceOnFoil ?? 0, system: .metric, statistics: true))
                    ScreenshotInfoRow(title: "Calories", value: "\(Int((statisticsData.kCalories ?? 0).rounded())) kcal")
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct ScreenshotMetricGrid: View {
    let statistic: RunStatistic

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ScreenshotMetricCard(title: "Distance", value: makePrettyDistance(meters: statistic.runDistance, system: .metric, statistics: true))
            ScreenshotMetricCard(title: "Time", value: makePrettyTime(timeInMinutes: statistic.runTime))
            ScreenshotMetricCard(title: "Average", value: makePrettySpeed(speed: statistic.averageSpeed ?? 0, system: .metric))
            ScreenshotMetricCard(title: "Top Speed", value: makePrettySpeed(speed: statistic.topSpeed, system: .metric))
        }
    }
}

private struct ScreenshotMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ScreenshotFilterMockView: View {
    let title: String
    let selectedTab: String
    let highlightedFilters: [String]
    let statistics: [RunStatistic]

    private let tabs = ["Tags", "Places", "Sports", "More"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.largeTitle.weight(.bold))

                HStack(spacing: 10) {
                    ForEach(tabs, id: \.self) { tab in
                        Text(tab)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tab == selectedTab ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                tab == selectedTab ? Color.accentColor : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Selected Filters")
                        .font(.headline.weight(.semibold))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                        ForEach(highlightedFilters, id: \.self) { filter in
                            ScreenshotTagChip(title: filter)
                        }
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Matching Sessions")
                        .font(.headline.weight(.semibold))

                    ForEach(statistics) { statistic in
                        ScreenshotResultCard(statistic: statistic)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct ScreenshotResultCard: View {
    let statistic: RunStatistic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(makeStringFromDate(statistic.startDate ?? .now))
                    .fontWeight(.bold)
                Text(statistic.workoutType?.prettyString ?? "DW SUP Foil")
                    .fontWeight(.bold)
                    .foregroundStyle(.accent)
                Spacer()
            }

            if let location = statistic.locationString {
                Text(location)
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 10) {
                Text(makePrettyDistance(meters: statistic.runDistance, system: .metric, statistics: true))
                Text(makePrettyTime(timeInMinutes: statistic.runTime))
                Text(makePrettySpeed(speed: statistic.averageSpeed ?? 0, system: .metric))
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let tags = statistic.tags, !tags.isEmpty {
                Text(tags.prefix(3).joined(separator: " "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.accent)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ScreenshotStatisticSummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("2026")
                .font(.title2.weight(.bold))

            ScreenshotInfoRow(title: "Sessions", value: "26 sessions on 14 days")
            ScreenshotInfoRow(title: "Water Time", value: "18 h 42 min")
            ScreenshotInfoRow(title: "Distance", value: "412 km total")
            ScreenshotInfoRow(title: "Downwind", value: "298 km")
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ScreenshotInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ScreenshotInstructionBanner: View {
    let text: String
    let color: Color

    var body: some View {
        HStack {
            Spacer()
            Label(text, systemImage: "plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(color, in: Capsule())
            Spacer()
        }
    }
}

private enum ScreenshotMapMode {
    case simple
    case edit
    case angleTool
}

private struct ScreenshotMapMockView: View {
    let mode: ScreenshotMapMode

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.96, blue: 0.98),
                        Color(red: 0.82, green: 0.89, blue: 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ScreenshotMapGrid()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)

                routePath(in: size)
                    .stroke(Color("neonYellow"), style: StrokeStyle(lineWidth: mode == .edit ? 12 : 10, lineCap: .round, lineJoin: .round))

                if mode == .edit {
                    editPath(in: size)
                        .stroke(Color.purple.opacity(0.45), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [1, 18]))
                }

                markers(in: size)

                if mode == .edit {
                    editHandles(in: size)
                }

                if mode == .angleTool {
                    angleLines(in: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private func routePath(in size: CGSize) -> Path {
        Path { path in
            let start = CGPoint(x: size.width * 0.18, y: size.height * 0.18)
            let midOne = CGPoint(x: size.width * 0.40, y: size.height * 0.30)
            let midTwo = CGPoint(x: size.width * 0.34, y: size.height * 0.55)
            let midThree = CGPoint(x: size.width * 0.68, y: size.height * 0.62)
            let end = CGPoint(x: size.width * 0.78, y: size.height * 0.84)

            path.move(to: start)
            path.addCurve(to: midOne, control1: CGPoint(x: size.width * 0.24, y: size.height * 0.14), control2: CGPoint(x: size.width * 0.38, y: size.height * 0.20))
            path.addCurve(to: midTwo, control1: CGPoint(x: size.width * 0.44, y: size.height * 0.38), control2: CGPoint(x: size.width * 0.28, y: size.height * 0.44))
            path.addCurve(to: midThree, control1: CGPoint(x: size.width * 0.42, y: size.height * 0.70), control2: CGPoint(x: size.width * 0.60, y: size.height * 0.50))
            path.addCurve(to: end, control1: CGPoint(x: size.width * 0.76, y: size.height * 0.70), control2: CGPoint(x: size.width * 0.70, y: size.height * 0.80))
        }
    }

    private func editPath(in size: CGSize) -> Path {
        Path { path in
            let points = [
                CGPoint(x: size.width * 0.18, y: size.height * 0.18),
                CGPoint(x: size.width * 0.32, y: size.height * 0.22),
                CGPoint(x: size.width * 0.46, y: size.height * 0.44),
                CGPoint(x: size.width * 0.59, y: size.height * 0.56),
                CGPoint(x: size.width * 0.78, y: size.height * 0.84)
            ]

            path.addLines(points)
        }
    }

    @ViewBuilder
    private func markers(in size: CGSize) -> some View {
        Group {
            Circle()
                .fill(Color.green)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .frame(width: 22, height: 22)
                .position(x: size.width * 0.18, y: size.height * 0.18)

            Circle()
                .fill(Color.red)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .frame(width: 22, height: 22)
                .position(x: size.width * 0.78, y: size.height * 0.84)
        }
    }

    @ViewBuilder
    private func editHandles(in size: CGSize) -> some View {
        ForEach(0..<4, id: \.self) { index in
            let points = [
                CGPoint(x: size.width * 0.18, y: size.height * 0.18),
                CGPoint(x: size.width * 0.32, y: size.height * 0.22),
                CGPoint(x: size.width * 0.46, y: size.height * 0.44),
                CGPoint(x: size.width * 0.59, y: size.height * 0.56)
            ]

            Circle()
                .fill(Color.purple.opacity(0.88))
                .frame(width: 16, height: 16)
                .position(points[index])
        }
    }

    @ViewBuilder
    private func angleLines(in size: CGSize) -> some View {
        let first = [
            CGPoint(x: size.width * 0.28, y: size.height * 0.58),
            CGPoint(x: size.width * 0.42, y: size.height * 0.42),
            CGPoint(x: size.width * 0.56, y: size.height * 0.52)
        ]
        let second = [
            CGPoint(x: size.width * 0.46, y: size.height * 0.74),
            CGPoint(x: size.width * 0.61, y: size.height * 0.62),
            CGPoint(x: size.width * 0.73, y: size.height * 0.72)
        ]

        Group {
            anglePath(points: first)
                .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            anglePath(points: second)
                .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

            ScreenshotAngleBadge(text: "128°")
                .position(first[1])

            ScreenshotAngleBadge(text: "142°")
                .position(second[1])
        }
    }

    private func anglePath(points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
        }
    }
}

private struct ScreenshotMapGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stepX = rect.width / 5
        let stepY = rect.height / 6

        for index in 1..<5 {
            let x = stepX * CGFloat(index)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }

        for index in 1..<6 {
            let y = stepY * CGFloat(index)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }

        return path
    }
}

private struct ScreenshotAngleBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green, in: Capsule())
    }
}

extension ScreenshotSampleData {
    static let hyeresLocationData: [LocationData] = {
        let pts: [(Double, Double, Double)] = [
            (43.0797672165824, 6.124062049829139, 0.56),
            (43.079769983695066, 6.124040237285879, 0.26),
            (43.079773123764326, 6.124038087456444, 0.22),
            (43.0797767675385, 6.124044907365882, 0.20),
            (43.079702162158156, 6.124055715427997, 0.97),
            (43.07966990341251, 6.124076982940096, 0.71),
            (43.079632137470654, 6.1240946973387524, 0.58),
            (43.07952534712388, 6.124129208367864, 2.12),
            (43.07940120240891, 6.124121005817502, 1.93),
            (43.07925607098462, 6.124210418584162, 1.48),
            (43.07912509315305, 6.12425421354217, 1.90),
            (43.0789620980598, 6.124369748135672, 2.58),
            (43.078884808315934, 6.124516754213544, 1.32),
            (43.07887793317617, 6.124473496321495, 0.96),
            (43.07880687121918, 6.124525220294524, 2.15),
            (43.078607019066595, 6.124630184310839, 3.08),
            (43.07836280646359, 6.124747048584156, 4.49),
            (43.07804701763434, 6.1246102873413495, 4.45),
            (43.07769460169871, 6.124377168523306, 6.32),
            (43.077439254908995, 6.124066247509632, 4.51),
            (43.07711754136207, 6.123827708615199, 5.67),
            (43.07683460404042, 6.123542203046317, 4.21),
            (43.07650336341083, 6.123372341300499, 5.22),
            (43.07618799350752, 6.123138323215446, 5.29),
            (43.07579337670654, 6.122938664332178, 6.14),
            (43.07540415538389, 6.122673181478534, 6.64),
            (43.07502037193169, 6.122309801959208, 5.45),
            (43.07466878385021, 6.122085414260237, 5.21),
            (43.07432868043851, 6.121952187469961, 5.04),
            (43.073926086248704, 6.121800160783477, 5.68),
            (43.073604482703296, 6.121539607930841, 4.80),
            (43.07327403431994, 6.121382794389479, 5.34),
            (43.07288624624252, 6.121199051355788, 5.62),
            (43.07252406090758, 6.120943917605942, 5.05),
            (43.07210442785231, 6.120705170720028, 6.75),
            (43.07172444334408, 6.1204440219933405, 6.99),
            (43.071292787308685, 6.120120678402972, 6.30),
            (43.070919894267604, 6.119851454039647, 5.45),
            (43.07084369904252, 6.119844146894251, 0.74),
            (43.0707870829788, 6.119920240591259, 1.61),
            (43.070611723472496, 6.120073401179215, 4.54),
            (43.070257906714154, 6.1198947473849765, 5.64),
            (43.069942134576614, 6.119661814628986, 5.31),
            (43.06982195215632, 6.119971151876459, 2.30),
            (43.069778121852714, 6.120065875198763, 0.43),
            (43.06975500690219, 6.120120282577319, 1.98),
            (43.0697502136359, 6.120149688730021, 0.06),
            (43.06968140825673, 6.120231016523988, 1.50),
            (43.069467401867925, 6.120311166795215, 4.51),
            (43.06940394921411, 6.1204951927667555, 5.23),
            (43.06972073019087, 6.12033252213652, 5.84),
            (43.07000370489794, 6.119903017218622, 5.32),
            (43.07027683513578, 6.119514754256308, 5.60),
            (43.07055231803804, 6.119154176786138, 5.26),
            (43.070821358849976, 6.118772494796688, 5.05),
            (43.07113166991547, 6.1184391855687545, 5.75),
            (43.071450175389586, 6.118002413118355, 6.57),
            (43.071711061836545, 6.117526254322385, 5.26),
            (43.07202198961821, 6.1171521841302035, 6.57),
            (43.072367233829866, 6.116686739714183, 6.28),
            (43.072686361974405, 6.1162621203373115, 6.04),
            (43.072992376055836, 6.115824512409776, 4.71),
            (43.07330352105488, 6.115523584296569, 5.27),
            (43.07360329930376, 6.115175972607981, 5.27),
            (43.073923815952845, 6.114876301845382, 5.20),
            (43.07424710754203, 6.114605520995061, 5.75),
            (43.07454388866495, 6.114295702821209, 5.41),
            (43.07484775186317, 6.1140054012023, 5.81),
            (43.07517769407511, 6.113669949267152, 5.77),
            (43.075488543373254, 6.113377945918674, 5.18),
            (43.07581240548854, 6.113138374467425, 5.23),
            (43.07612342571076, 6.112905926305647, 5.63),
            (43.076473141151695, 6.112611736206408, 6.00),
            (43.076849578358235, 6.112306968295544, 6.50),
            (43.077174227268436, 6.1120454282843495, 5.09),
            (43.07749522855784, 6.111782921938526, 5.84),
            (43.077834761560084, 6.111498606084578, 5.13),
            (43.078186920017586, 6.111555633076571, 6.04),
            (43.07806554913997, 6.112052479551694, 4.81),
            (43.07806809859956, 6.112485097429081, 4.31),
            (43.078113217338235, 6.112863821039187, 5.09),
            (43.078105054921444, 6.113426580904317, 7.04),
            (43.077986088137685, 6.114113727387576, 6.34),
            (43.077755427380225, 6.11471703846483, 7.15),
            (43.07765862050262, 6.115287172671884, 5.63),
            (43.07777400574887, 6.115854829381957, 6.83),
            (43.07748607318314, 6.116312896707368, 5.67),
            (43.07749095121254, 6.116941126492983, 4.96),
            (43.07758608384466, 6.117231006187604, 5.05),
            (43.077780738143865, 6.117649073753745, 6.14),
            (43.077982672125934, 6.1180079779040115, 6.88),
            (43.07792435564456, 6.11844900873385, 6.10),
            (43.07781684649485, 6.118980680861979, 5.72),
            (43.07783251961665, 6.119520694768033, 6.51),
            (43.0778659310082, 6.120023793287987, 7.21),
            (43.078073690961794, 6.120463301466439, 6.59),
            (43.078160954833756, 6.120949355982941, 6.17),
            (43.07822085160505, 6.121471451822732, 6.90),
            (43.07812594537517, 6.121854127377946, 4.51),
            (43.0782684420938, 6.122285241840531, 5.52),
            (43.07829763361693, 6.122744394835709, 6.21),
            (43.078146029702886, 6.123272074708852, 5.59),
            (43.07795246719478, 6.123631620857059, 4.33),
            (43.07794137874017, 6.1240380547076985, 3.89),
            (43.077917667389265, 6.124208761812062, 0.38),
            (43.07791572229964, 6.124227896780195, 0.24),
            (43.077938798225894, 6.12426436157326, 0.12),
            (43.07793899645808, 6.124275006174294, 0.23),
            (43.077938519517105, 6.124317391312526, 0.41),
            (43.07793280633311, 6.124377429762164, 0.03),
            (43.07793055447069, 6.1243981420196, 0.12),
            (43.07794655464154, 6.12441299898227, 0.16),
            (43.077959981317264, 6.12446351890887, 0.39),
            (43.07792730761627, 6.124526741627937, 0.91),
            (43.07781844739589, 6.124580824589198, 1.40),
            (43.07770388468859, 6.124618195977784, 2.49),
            (43.077493469973746, 6.124765123227436, 3.35),
            (43.07726926583802, 6.124879473266592, 4.26),
            (43.07693380580455, 6.124788012361663, 5.70),
            (43.07650444923816, 6.124506185103521, 6.71),
            (43.07611084899111, 6.124172604572063, 5.96),
            (43.07573980379998, 6.123885244441954, 5.86),
            (43.07534890742626, 6.123654180701249, 6.51),
            (43.074935275449754, 6.123339928626585, 5.49),
            (43.074524265054336, 6.123068703324784, 5.26),
            (43.07419135322267, 6.122866258569168, 6.11),
            (43.07380045945753, 6.122600953439852, 5.71),
            (43.073491577559956, 6.12238962961388, 4.36),
            (43.073560928358475, 6.122523576777046, 4.29),
            (43.073893560848404, 6.122399001834164, 4.10),
            (43.074151317708036, 6.122125707957677, 4.59),
            (43.07445716743697, 6.121824404920355, 5.65),
            (43.07475024795924, 6.121568406979185, 4.73),
            (43.07504791597781, 6.121301632223017, 5.15),
            (43.07536766416784, 6.121029326637414, 4.97),
            (43.075627267761604, 6.120748785767074, 4.50),
            (43.07593658488837, 6.120507147262448, 5.35),
            (43.076246582479236, 6.120179560586075, 5.66),
            (43.07654046671084, 6.119864103155641, 5.02),
            (43.07681898806874, 6.119596903615848, 4.68),
            (43.07712134046542, 6.119297147148614, 4.97),
            (43.07741178135278, 6.119027635471278, 5.36),
            (43.07772025244396, 6.118687674312393, 6.07),
            (43.077996791418464, 6.118363597902064, 4.52),
            (43.07785515955722, 6.118557200879084, 6.47),
            (43.07747975425162, 6.118233882651133, 5.84),
            (43.077144173656215, 6.117933246427695, 5.40),
            (43.07676746993357, 6.117700660481808, 6.16),
            (43.07639022555398, 6.117439921719637, 5.97),
            (43.07601291128404, 6.1171804464751265, 6.13),
            (43.07564023957995, 6.116895635258586, 6.28),
            (43.07530582674341, 6.11658606997434, 5.69),
            (43.07488368879783, 6.11629879191183, 6.61),
            (43.07452449736471, 6.115977781421793, 5.27),
            (43.074163232611276, 6.115725932069727, 5.66),
            (43.07380278280728, 6.11541470263561, 5.70),
            (43.07348972983002, 6.115161691595291, 5.63),
            (43.073558210787155, 6.115284418894022, 4.52),
            (43.07388040993475, 6.115161985885823, 4.48),
            (43.074182147146416, 6.11492904195316, 4.94),
            (43.07450976363091, 6.114621149901477, 5.82),
            (43.07478638567934, 6.114299095416976, 5.27),
            (43.07509367546239, 6.113960483131162, 5.71),
            (43.07538565540565, 6.1136811871612355, 5.01),
            (43.07570454133274, 6.113571828078409, 4.04),
            (43.07600560002712, 6.113421397743418, 5.46),
            (43.07632036905887, 6.113121049943947, 5.12),
            (43.07665197950424, 6.112852456589732, 5.12),
            (43.07693983053639, 6.112520966808529, 5.04),
            (43.077229940094966, 6.112273758483514, 5.00),
            (43.07718361970415, 6.112506283307542, 4.99),
            (43.07687284832451, 6.112273857931969, 4.72),
            (43.07651729627444, 6.112000704984902, 6.67),
            (43.0761971535658, 6.1116217285106975, 5.13),
            (43.07608117585274, 6.111937994231162, 5.52),
            (43.076106643059525, 6.112311575243406, 2.91),
            (43.076087591072586, 6.112513270904553, 0.97),
            (43.07600743752071, 6.112589264240398, 2.87),
            (43.0757554203064, 6.1126591617754285, 4.82),
            (43.07548831932183, 6.1124920149139115, 4.66),
            (43.07537068094767, 6.112864741746316, 5.42),
            (43.075669425395226, 6.113319736130547, 7.06),
            (43.07598047973742, 6.113681738166499, 4.91),
            (43.076296905145576, 6.1140212296341, 7.40),
            (43.07667379650229, 6.114338134403975, 5.94),
            (43.076583421340366, 6.114925157709556, 5.41),
            (43.07692919574809, 6.115324716809905, 5.91),
            (43.0771670868326, 6.115834241789626, 6.90),
            (43.0773116293409, 6.116384688692463, 5.24),
            (43.077364747557226, 6.116881311854297, 4.25),
            (43.07754666715447, 6.117288157054107, 5.26),
            (43.077863111168085, 6.117602004490858, 5.83),
            (43.07811975063308, 6.117941543998963, 5.63),
            (43.07826814496887, 6.1182676603522435, 4.01),
            (43.078338188350294, 6.118752064562652, 5.26),
            (43.07848548266128, 6.119240473188002, 6.72),
            (43.0785948514748, 6.119832296558969, 8.00),
            (43.078363376265365, 6.1202894492774504, 5.78),
            (43.078580378742615, 6.120383583326453, 5.88),
            (43.07842657006615, 6.1208033129077855, 7.73),
            (43.07812295867865, 6.121108219067654, 5.67),
            (43.078054216959934, 6.121468862761342, 4.80),
            (43.07790113850919, 6.121921628909409, 4.29),
            (43.07808009463707, 6.122377325969433, 6.00),
            (43.078332135998124, 6.122771963754111, 5.36),
            (43.07845322914159, 6.123156701818467, 4.92),
            (43.07859785376799, 6.123401691776068, 4.61),
            (43.07891117940985, 6.123720583579477, 5.23),
            (43.07911947970305, 6.124058929279505, 4.41),
            (43.07936428987852, 6.124266457617043, 4.06),
            (43.07945687832395, 6.124351966020249, 0.85),
            (43.079497344096765, 6.1243699551877935, 1.01),
            (43.07951809885664, 6.124377284441279, 0.67),
            (43.079540993885914, 6.124396547314618, 1.08),
            (43.07958417207099, 6.124383236342319, 0.74),
            (43.07959925896961, 6.1243870314245, 0.14)
        ]
        return pts.enumerated().map { i, p in
            LocationData(timestamp: Date.now.addingTimeInterval(Double(i)), latitude: p.0, longitude: p.1, altitude: 0, speed: p.2)
        }
    }()

    static func hyeresStatistic() -> RunStatistic {
        let locations = hyeresLocationData
        let statisticID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        var statistic = RunStatistic(
            id: statisticID,
            runName: "Parawing",
            crewStatistics: [],
            runTime: 28.7,
            runDistance: 7877,
            topSpeed: 31.0,
            averageSpeed: 16.5,
            kCalories: 480,
            locationData: locations,
            tags: ["#parawing", "#hyeres"],
            workoutType: .parawing,
            startDate: locations.first?.timestamp ?? Date.now,
            endDate: locations.last?.timestamp ?? Date.now,
            topSpeed1s: 32.4,
            topSpeed10s: 27.8,
            popUps: 0,
            percentageOnFoil: 0,
            turnsCount: 0
        )
        statistic.locationString = "Hyères"
        statistic.startLocation = locations.first
        statistic.angles = hyeresAngles()
        return statistic
    }

    static func hyeresAngles() -> [MapAngle] {
        return [
            MapAngle(coordinates: [
                CLLocationCoordinate2D(latitude: 43.076089046921474, longitude: 6.124187359372671),
                CLLocationCoordinate2D(latitude: 43.073808400052364, longitude: 6.122603187760369),
                CLLocationCoordinate2D(latitude: 43.07531386120208, longitude: 6.121049776761961)
            ]),
            MapAngle(coordinates: [
                CLLocationCoordinate2D(latitude: 43.07222425547819, longitude: 6.120757550930533),
                CLLocationCoordinate2D(latitude: 43.0703704172785, longitude: 6.1194502248426605),
                CLLocationCoordinate2D(latitude: 43.07217931460928, longitude: 6.116927854508595)
            ]),
            MapAngle(coordinates: [
                CLLocationCoordinate2D(latitude: 43.0757744799857, longitude: 6.120680649395952),
                CLLocationCoordinate2D(latitude: 43.07786407293706, longitude: 6.118512026120897),
                CLLocationCoordinate2D(latitude: 43.075662134260135, longitude: 6.116881713587806)
            ])
        ]
    }
}


extension ScreenshotSampleData {
    static let parawingDownwindRunLocations: [LocationData] = {
        let pts: [(Double, Double, Double)] = [
            (46.891924127364604, 6.7783236617332285, 0.0),
            (46.891923957268126, 6.778324732145307, 0.0),
            (46.89192569968388, 6.778339803985007, 0.1),
            (46.891942362821815, 6.77837742551487, 0.15),
            (46.891959097436114, 6.778412960486299, 0.47),
            (46.89196854457852, 6.77843942047509, 0.19),
            (46.89197217180633, 6.778451130381309, 0.08),
            (46.89197166029162, 6.778445018028214, 0.14),
            (46.89197579798713, 6.778433989691109, 0.22),
            (46.89198684044665, 6.778423518578703, 0.12),
            (46.891988061673196, 6.778412526887875, 0.15),
            (46.891985987420306, 6.7784048634105805, 0.22),
            (46.89197942015109, 6.778419234632638, 0.18),
            (46.89197125516728, 6.778433080737863, 0.14),
            (46.89197546387019, 6.778435586787782, 0.41),
            (46.8919823962878, 6.77844294102063, 0.06),
            (46.89197255700505, 6.7784429197603915, 0.3),
            (46.89195675141381, 6.7784425175150265, 0.12),
            (46.89195679324461, 6.7784393418552185, 0.85),
            (46.891957243928125, 6.778449666484898, 0.32),
            (46.891967904194004, 6.778453641623984, 0.12),
            (46.89198936012278, 6.77845216904136, 0.3),
            (46.891994061572674, 6.778449586945592, 0.21),
            (46.891998491757384, 6.778450198531429, 0.17),
            (46.89199794261485, 6.778453214929526, 0.41),
            (46.8919963860864, 6.778454326573806, 0.18),
            (46.89199105858403, 6.77845623941982, 0.26),
            (46.89198450404053, 6.778454776991764, 0.28),
            (46.89197569928429, 6.778450123068752, 0.4),
            (46.89197751157491, 6.778446509712478, 1.14),
            (46.891981889543544, 6.778460692214277, 0.58),
            (46.891980597048835, 6.778494079715586, 1.65),
            (46.89196342510213, 6.7785380008300615, 1.31),
            (46.89194669646498, 6.778574287333645, 0.45),
            (46.89194241827057, 6.778598501950782, 0.45),
            (46.891943044846386, 6.77862869751337, 0.91),
            (46.89194043299242, 6.778659674164899, 0.81),
            (46.89193534956017, 6.778690010437495, 0.86),
            (46.89193116157649, 6.778725566804523, 0.59),
            (46.89193313740461, 6.778751506850558, 0.56),
            (46.89193247743168, 6.778774674686814, 0.63),
            (46.89192956490973, 6.778788137778404, 1.06),
            (46.891929219749706, 6.77883149528139, 1.95),
            (46.89191951939249, 6.77891017846552, 2.67),
            (46.891908641636974, 6.77897824734301, 1.76),
            (46.89190793137417, 6.779033933946232, 0.58),
            (46.891904125021824, 6.779051076461381, 0.4),
            (46.89190861976453, 6.779034707751035, 0.76),
            (46.89191507269744, 6.7790109510752, 0.05),
            (46.891923344216536, 6.778999364680584, 0.15),
            (46.89193872134262, 6.778984934404349, 0.46),
            (46.891944759393375, 6.778978747610161, 0.2),
            (46.89194978407473, 6.778983803774559, 0.31),
            (46.891956270533754, 6.7789862547941775, 0.32),
            (46.891961449894104, 6.7789903915168095, 0.44),
            (46.89196316659564, 6.7789981220448885, 0.29),
            (46.89196910632261, 6.779013888181411, 0.64),
            (46.89197462936083, 6.779022628973391, 0.21),
            (46.89198794120989, 6.779041709827839, 1.18),
            (46.89199743875795, 6.779082595099546, 1.04),
            (46.891999551370716, 6.779156515052414, 2.21),
            (46.89199894497609, 6.779235329037944, 1.3),
            (46.89199324899606, 6.7793279664678785, 2.41),
            (46.89199081113424, 6.779430627815157, 2.58),
            (46.89198362470975, 6.779539401851715, 2.56),
            (46.89198147576157, 6.779631996615232, 1.47),
            (46.89198091969608, 6.779727853388272, 2.39),
            (46.89198037403697, 6.779819565455795, 2.6),
            (46.8919968257975, 6.779917995152679, 2.63),
            (46.89202862045241, 6.780035979707629, 3.35),
            (46.89205943174788, 6.780173314137775, 4.53),
            (46.89208863693217, 6.780346760298459, 4.77),
            (46.892119504744, 6.780551944034836, 5.81),
            (46.89214098318875, 6.7807784191955065, 3.3),
            (46.892158019486175, 6.7810285371825385, 6.67),
            (46.89215886401069, 6.78130828242251, 6.85),
            (46.89212747078197, 6.781580905238499, 6.53),
            (46.89208956178457, 6.78184051259902, 5.96),
            (46.892045182352746, 6.782078215313253, 5.77),
            (46.89202428762481, 6.782320090967772, 6.71),
            (46.8920408603769, 6.782567153779605, 6.16),
            (46.89202851694812, 6.782799352898748, 5.47),
            (46.891998171378084, 6.783028267839099, 6.55),
            (46.89195741770159, 6.7832661782135375, 6.31),
            (46.891917712641145, 6.783503566344002, 6.27),
            (46.891891108830784, 6.7837441797083, 6.12),
            (46.89186697766056, 6.783986754015363, 6.08),
            (46.89184524022108, 6.78423497169094, 6.46),
            (46.891827416774554, 6.784487469843956, 6.6),
            (46.89179568916155, 6.784733868450596, 6.11),
            (46.89177178029791, 6.784983251951492, 6.28),
            (46.89178068538986, 6.785240969729181, 6.94),
            (46.89179402009819, 6.785508433149706, 6.9),
            (46.89181753718329, 6.785778474369318, 6.57),
            (46.89183301703984, 6.786036577144513, 6.4),
            (46.89184555318793, 6.786285944944938, 6.68),
            (46.89185930846628, 6.786546583333709, 6.93),
            (46.89188149093749, 6.786810115781786, 6.54),
            (46.891907351862095, 6.787064393398716, 6.27),
            (46.891929079458514, 6.787309114404172, 6.39),
            (46.891959182391545, 6.787552309710729, 6.09),
            (46.891961667978315, 6.787779270327764, 5.86),
            (46.89193154916359, 6.78800601309407, 6.42),
            (46.89194053299475, 6.788245237432982, 6.18),
            (46.89196004689109, 6.788487732302507, 6.42),
            (46.89196428055457, 6.788745813874321, 7.11),
            (46.89196966626123, 6.789026577558125, 7.07),
            (46.89197812510251, 6.789301463802982, 6.29),
            (46.89196989933819, 6.78955138532962, 5.96),
            (46.891963619908445, 6.7897822036082625, 5.73),
            (46.891967814990906, 6.789997292898285, 5.6),
            (46.89193820196861, 6.790208771981364, 6.13),
            (46.89191610199482, 6.790445243095011, 6.37),
            (46.891923908663294, 6.7906756911644, 5.47),
            (46.8919012156739, 6.790894858784911, 5.81),
            (46.89184165549423, 6.791108016094916, 6.07),
            (46.89178061566904, 6.791319685334902, 6.07),
            (46.89173959655374, 6.7915488063634415, 6.05),
            (46.89168179009089, 6.791765711009761, 5.8),
            (46.891586100722705, 6.7919414254841834, 5.48),
            (46.89147805417867, 6.792105684638365, 5.74),
            (46.8913734392736, 6.792271975655579, 5.61),
            (46.891299983974776, 6.792463928308445, 5.66),
            (46.89125237218263, 6.792672218685596, 6.15),
            (46.891262628096335, 6.792907024373701, 6.05),
            (46.891274296922525, 6.793165774668565, 6.74),
            (46.891291075620025, 6.793436438323248, 6.42),
            (46.89131592168402, 6.793703877623747, 6.44),
            (46.89130987009121, 6.7939571331852, 6.4),
            (46.89127379454153, 6.794201541101082, 6.04),
            (46.89124002825229, 6.794428205052562, 5.94),
            (46.89126147360116, 6.794644051753216, 5.79),
            (46.891271602812694, 6.794859022418128, 5.68),
            (46.891276983221246, 6.795082509331099, 5.84),
            (46.8913133243889, 6.795297586461346, 5.51),
            (46.89132877848847, 6.795508638345861, 5.47),
            (46.89141458681722, 6.795639321143704, 4.93),
            (46.89154717208253, 6.795599485145869, 5.95),
            (46.891681937023506, 6.795449968901033, 5.35),
            (46.891808564055296, 6.79525408598259, 5.56),
            (46.89191092489612, 6.795041771655381, 5.01),
            (46.89200852239887, 6.794848622318398, 5.33),
            (46.892095671134435, 6.794661286297142, 5.03),
            (46.89219619871645, 6.794531560558236, 4.53),
            (46.89231553612461, 6.794464424183195, 5.02),
            (46.892442285452745, 6.794430390764875, 4.07),
            (46.892597672484264, 6.794435512410235, 5.81),
            (46.89276399809466, 6.794418140425525, 6.72),
            (46.89290981181697, 6.7945237849826094, 6.09),
            (46.89295182308694, 6.794740017602937, 5.65),
            (46.892908157090446, 6.794988892952857, 5.78),
            (46.89279436983361, 6.795199138369937, 5.67),
            (46.892710754656434, 6.795400745852076, 6.03),
            (46.89269353521112, 6.795630721075054, 5.86),
            (46.8926995563339, 6.795846349859642, 4.6),
            (46.89275905546936, 6.796042142950758, 5.74),
            (46.892802245248866, 6.796245174766181, 5.39),
            (46.89284758679798, 6.796455133594519, 5.81),
            (46.89291585197623, 6.796649099722492, 4.9),
            (46.89302244465756, 6.796724438245161, 5.27),
            (46.89315111409018, 6.796740979984284, 5.14),
            (46.893271332697445, 6.796778690208819, 5.19),
            (46.89341122159336, 6.796720217661531, 5.16),
            (46.89354544133611, 6.796626427672631, 5.96),
            (46.89365735880227, 6.796699808983704, 5.26),
            (46.89378217148296, 6.796755207545433, 5.9),
            (46.893920288546596, 6.796732665419105, 5.5),
            (46.894062755117844, 6.79667952616634, 5.26),
            (46.89416776572061, 6.796755696863677, 4.86),
            (46.89426523726698, 6.796896813913486, 5.38),
            (46.89437862499852, 6.797011476138823, 4.04),
            (46.894518355330455, 6.797017701956835, 6.74),
            (46.894647746284356, 6.796907015850329, 5.38),
            (46.89478166392713, 6.796810787473185, 5.29),
            (46.89491502127694, 6.796702728881209, 5.52),
            (46.8950613766283, 6.79665763098729, 5.71),
            (46.89520895854269, 6.7967343894119745, 6.62),
            (46.89529146096832, 6.796938076650136, 6.81),
            (46.895292754661575, 6.797196411609168, 5.79),
            (46.895267659609154, 6.7974726481165755, 5.24),
            (46.89522701665953, 6.797711679295798, 4.61),
            (46.8952808422007, 6.7978313253896845, 5.62),
            (46.89539450203469, 6.7979010023498745, 6.07),
            (46.89549158107394, 6.798018616896122, 5.12),
            (46.89561228949375, 6.798120239615877, 4.58),
            (46.89574968870815, 6.7981308498684205, 5.33),
            (46.89588684285727, 6.7980887289921705, 3.98),
            (46.89602904135304, 6.798016138525249, 4.46),
            (46.89615889527071, 6.7980253199709875, 5.46),
            (46.89624573191267, 6.798161005944399, 5.76),
            (46.896261259274766, 6.79839179419115, 6.41),
            (46.896253645681206, 6.798646360659703, 5.48),
            (46.896268174029245, 6.7988881976695446, 5.07),
            (46.89635374179671, 6.798988969968436, 5.31),
            (46.89648197994349, 6.798953645279153, 5.45),
            (46.896613837238014, 6.798854590370438, 5.27),
            (46.896708608762644, 6.79892188079321, 4.83),
            (46.89675341247194, 6.799082754104454, 5.05),
            (46.896772138917235, 6.799303305995421, 5.73),
            (46.896784211249404, 6.799557002136123, 6.03),
            (46.89680581556861, 6.799825410233788, 6.22),
            (46.896875819332095, 6.800065839651002, 5.4),
            (46.89700290652486, 6.800152169838723, 5.79),
            (46.89713882322437, 6.800189800169897, 6.11),
            (46.897218896016206, 6.800329570536007, 5.68),
            (46.89729373135295, 6.80051993844113, 6.37),
            (46.89735377578566, 6.80074860442087, 6.11),
            (46.89744609922825, 6.800954916465057, 5.66),
            (46.89753940153242, 6.801112420280064, 5.38),
            (46.89767052268327, 6.8011117740910985, 5.2),
            (46.89779875985179, 6.801123050254236, 4.83),
            (46.89792815027724, 6.801135761189697, 5.93),
            (46.89796093011464, 6.80127910376516, 5.54),
            (46.89801829924614, 6.801374299444835, 5.15),
            (46.898115603051366, 6.801343719701679, 5.13),
            (46.89824020374052, 6.8012934022704, 6.19),
            (46.8983499494062, 6.8013825877210685, 5.46),
            (46.898431977633145, 6.801554596126815, 6.13),
            (46.89846260946265, 6.80179014102377, 5.95),
            (46.89850558717467, 6.802040072206919, 6.09),
            (46.89857241012906, 6.802264818227497, 5.61),
            (46.898659702813184, 6.80247190874924, 6.25),
            (46.89870141460617, 6.802704236850694, 6.08),
            (46.89865270020639, 6.802921701647602, 5.0),
            (46.89865928958874, 6.803122389695745, 6.42),
            (46.898717970280536, 6.803315024113145, 5.71),
            (46.89880061653876, 6.803494162986885, 5.51),
            (46.898873282472536, 6.803688138228481, 5.89),
            (46.898928570541884, 6.803916361075638, 5.75),
            (46.89897612821972, 6.8041568436161395, 6.11),
            (46.89901724678026, 6.8043859849417885, 6.25),
            (46.89897502627292, 6.804622446594431, 6.18),
            (46.89894821372983, 6.804818379032344, 5.24),
            (46.899039953093, 6.804892253358586, 6.13),
            (46.89914677925265, 6.804947846546218, 4.82),
            (46.89924977777112, 6.804992262403555, 4.62),
            (46.899381063594454, 6.804938532031188, 5.17),
            (46.89952969010648, 6.804890372945212, 5.62),
            (46.89963464417307, 6.804951706197645, 4.09),
            (46.89972171996905, 6.80508445065901, 4.75),
            (46.899823617684184, 6.80515755211607, 6.14),
            (46.89994991413266, 6.8051294131368785, 5.85),
            (46.90009552373496, 6.805047791153379, 5.82),
            (46.90023774167939, 6.8049318127675855, 6.08),
            (46.90036570277288, 6.804822679420961, 5.32),
            (46.90050247528212, 6.804711248420498, 5.53),
            (46.900644940048245, 6.804654722897885, 6.17),
            (46.90072802011704, 6.804803742833377, 5.81),
            (46.90077439232041, 6.80504282673527, 6.27),
            (46.90076470305932, 6.805327008854805, 6.64),
            (46.90070018175055, 6.8055990968812905, 4.49),
            (46.90070006740225, 6.805823072989386, 5.1),
            (46.900792201988075, 6.8059474027276385, 5.29),
            (46.900829500778386, 6.8060998269908115, 4.63),
            (46.90084114019064, 6.806299592265116, 6.04),
            (46.90082017646388, 6.806524744165805, 5.89),
            (46.90079887156088, 6.806732697428405, 4.43),
            (46.900884551527795, 6.806809482715536, 5.62),
            (46.90101390806358, 6.806734189021103, 5.02),
            (46.90117064367039, 6.806694287086931, 5.51),
            (46.90132895197886, 6.8066624091575445, 5.49),
            (46.90143630447042, 6.806780319924029, 5.81),
            (46.901460836541055, 6.806993470889764, 6.16),
            (46.9015155514946, 6.807236981022938, 6.21),
            (46.90158749816461, 6.80745860623051, 4.32),
            (46.90166727972392, 6.807614660280566, 5.06),
            (46.90169064021141, 6.807784508975154, 5.3),
            (46.90167488839145, 6.807944113373552, 1.79),
            (46.90163922437389, 6.808084297648831, 5.25),
            (46.901651655110015, 6.808293126748592, 6.16),
            (46.901704347980534, 6.808462631393325, 1.99),
            (46.90183723550319, 6.8086472336480215, 6.05),
            (46.90193446926772, 6.808863310577452, 6.13),
            (46.90204903221547, 6.80895029555269, 4.55),
            (46.902137725435495, 6.809044730901738, 4.38),
            (46.90223252610892, 6.8091730536416435, 5.73),
            (46.902296085589924, 6.8093562649376205, 5.42),
            (46.90228396733177, 6.809607226893186, 5.52),
            (46.90230005424533, 6.809819035111531, 5.58),
            (46.90240756142359, 6.809846534293494, 5.72),
            (46.90255484356593, 6.809788829044825, 5.36),
            (46.90270317060414, 6.809715324826995, 4.44),
            (46.90286062686769, 6.8096719317564105, 5.52),
            (46.902957850677446, 6.809768525651279, 5.61),
            (46.90301718789414, 6.809973775148381, 6.22),
            (46.90304087263812, 6.810233824677271, 6.14),
            (46.90299038297657, 6.810511650186154, 6.34),
            (46.902945074702096, 6.810767014006496, 5.33),
            (46.90298802227971, 6.810937358943061, 5.6),
            (46.90311955744081, 6.810954538992127, 5.2),
            (46.903232634465276, 6.811070246407599, 6.61),
            (46.90329942703773, 6.811245245724108, 5.33),
            (46.90328211121271, 6.811468572980434, 6.65),
            (46.90326646598318, 6.811667253749909, 5.58),
            (46.90333946282888, 6.811727210102538, 2.96),
            (46.9034126243888, 6.811829162774418, 4.3),
            (46.90354546875673, 6.811791735631507, 6.32),
            (46.90370229847783, 6.811762821955772, 5.0),
            (46.9038211825803, 6.811832202173632, 4.24),
            (46.90396625217459, 6.811809151427985, 5.4),
            (46.904096096573305, 6.8118116547603105, 4.96),
            (46.90415153745147, 6.811954192332696, 5.14),
            (46.90416666554985, 6.812162048218761, 5.44),
            (46.904147146241385, 6.812398723893066, 5.22),
            (46.90414699075484, 6.812646794408125, 5.86),
            (46.90415197485981, 6.812897999953108, 5.57),
            (46.904225790541524, 6.813023565854773, 4.89),
            (46.90436170694389, 6.813040510236578, 5.63),
            (46.904507076200815, 6.812985882740863, 5.11),
            (46.90464029368107, 6.812960672875356, 5.6),
            (46.904765391843284, 6.81296405945209, 6.21),
            (46.90487185162, 6.813035790003247, 6.45),
            (46.90494673027028, 6.81317208032557, 4.8),
            (46.90504169333602, 6.813276904748564, 5.72),
            (46.905068083732225, 6.81347361848043, 5.56),
            (46.90512579951952, 6.813672530451961, 5.93),
            (46.90520170128968, 6.8138675263964705, 5.55),
            (46.90527212867365, 6.814078458346227, 5.87),
            (46.90534337690139, 6.814300643583362, 5.98),
            (46.90541240462555, 6.814517244713928, 6.46),
            (46.90539342583615, 6.81473940182772, 5.47),
            (46.90540214772685, 6.814921395696612, 5.09),
            (46.905468098249976, 6.81505785797748, 5.69),
            (46.905521779269414, 6.815241089871281, 6.08),
            (46.90556457955798, 6.815456701361005, 5.57),
            (46.90559516136026, 6.815684902500422, 5.85),
            (46.90559012552731, 6.815919879060472, 5.52),
            (46.905575788843436, 6.81614452331433, 6.1),
            (46.905608704554496, 6.816362925751755, 5.85),
            (46.905645516924366, 6.816557701195756, 4.79),
            (46.90568930375188, 6.816735516647094, 5.12),
            (46.905810854024196, 6.8168351277889485, 5.56),
            (46.905946799185116, 6.816857736094506, 5.41),
            (46.90607314271956, 6.816944096908432, 4.48),
            (46.90620035230912, 6.81697275952828, 5.55),
            (46.906312554722604, 6.817081821132658, 5.86),
            (46.906417403907724, 6.817197978697609, 6.29),
            (46.90652635015479, 6.817307725057672, 6.03),
            (46.90663926890472, 6.817393794256912, 5.03),
            (46.90674296470068, 6.8174414230702105, 4.75),
            (46.906857126081405, 6.817436088226534, 4.9),
            (46.90694054886239, 6.817542082653782, 5.72),
            (46.90701735734003, 6.817722132790344, 5.41),
            (46.90705975783199, 6.8179514056886115, 5.56),
            (46.90711715271593, 6.818205127711461, 6.93),
            (46.90715691523327, 6.818465927800869, 5.65),
            (46.907163304157535, 6.818713169842669, 6.21),
            (46.90713127367648, 6.818950314200903, 4.87),
            (46.907134176953655, 6.819164524387489, 4.94),
            (46.90716742096674, 6.819385511463513, 6.55),
            (46.90720945351064, 6.819630496738747, 6.0),
            (46.907269512421266, 6.819853330800682, 6.16),
            (46.90734379069674, 6.820080656175869, 6.88),
            (46.90741102540319, 6.820284989537384, 5.2),
            (46.90748724095119, 6.820473996837128, 5.89),
            (46.90753580127917, 6.820666911765179, 5.25),
            (46.907596375886186, 6.820849078299434, 5.19),
            (46.907705190374266, 6.820932590131455, 5.89),
            (46.907843768306726, 6.820939790837088, 5.66),
            (46.90798258632332, 6.820932119200331, 4.37),
            (46.908082634708784, 6.821030007364678, 5.4),
            (46.908157946159044, 6.821203151300038, 6.06),
            (46.908188945996706, 6.821438846235046, 5.94),
            (46.908205053436426, 6.821671617236865, 7.05),
            (46.9082528956268, 6.821893846699491, 4.81),
            (46.90834005753748, 6.821998779863567, 2.2),
            (46.908422104141856, 6.821974084858797, 2.44),
            (46.908541652887735, 6.821868494230333, 1.78),
            (46.90867945431984, 6.821790421316813, 5.32),
            (46.9088752375263, 6.821766894042003, 5.03),
            (46.909038358666166, 6.821783133724115, 4.92),
            (46.90916757759743, 6.821860735009684, 4.82),
            (46.90926353421947, 6.822026324904537, 5.11),
            (46.90931904333746, 6.822246607346129, 5.06),
            (46.9092999177809, 6.822572254010368, 6.03),
            (46.909177594318315, 6.8229855850855765, 5.18),
            (46.909155143625455, 6.8232781927520305, 5.75),
            (46.90920169245852, 6.82352174198296, 6.46),
            (46.90925073453493, 6.823733405853313, 5.92),
            (46.9093082896167, 6.823954732513326, 6.32),
            (46.90937332270356, 6.8241723277084345, 5.86),
            (46.90942228354208, 6.8243989697659835, 6.0),
            (46.909391424668634, 6.824612413371008, 5.47),
            (46.90940480833548, 6.8248311204932035, 6.42),
            (46.90945609777624, 6.825042097384787, 5.88),
            (46.90950695463235, 6.825251122673951, 5.79),
            (46.90952265089966, 6.825477999484299, 6.04),
            (46.90951037840452, 6.825701736489828, 5.48),
            (46.90951309057531, 6.82588166274105, 4.12),
            (46.9096250108656, 6.825943547276457, 6.49),
            (46.909780663132956, 6.825962272453297, 4.86),
            (46.909906712375296, 6.826045420280114, 5.09),
            (46.91004934961802, 6.8261206700247365, 4.66),
            (46.91012435132598, 6.826268146807761, 6.27),
            (46.91016866457495, 6.82650191311499, 6.4),
            (46.910206490629086, 6.826758208431377, 5.91),
            (46.91022096162972, 6.8270159548557325, 5.57),
            (46.91023942099924, 6.8272551555041545, 6.3),
            (46.91030994564841, 6.827484607500135, 6.2),
            (46.910385264659936, 6.827697106879275, 6.28),
            (46.910449782419136, 6.8279340205869135, 6.74),
            (46.91049167597412, 6.828174286655568, 5.86),
            (46.91051489205583, 6.828401994122617, 5.5),
            (46.91053538444449, 6.828617134712221, 5.72),
            (46.91057856370518, 6.828817574011892, 5.18),
            (46.91062782544986, 6.829008433902449, 5.96),
            (46.91064252576973, 6.829221274782144, 5.42),
            (46.9106821311854, 6.829433135763426, 5.9),
            (46.91072061045677, 6.829651431259168, 5.66),
            (46.91077110786758, 6.829842863834928, 5.61),
            (46.9108132404376, 6.8300249919078215, 5.51),
            (46.91088128522046, 6.83023172064488, 6.2),
            (46.91095175677044, 6.830441394926527, 6.58),
            (46.91099410186466, 6.830689358506627, 6.11),
            (46.91098891243871, 6.8309142547358155, 5.11),
            (46.91101875807543, 6.831121862597316, 5.67),
            (46.911045772104565, 6.8313399021058085, 5.63),
            (46.911041034444914, 6.831554337016839, 5.85),
            (46.91102111529178, 6.83176758204682, 5.7),
            (46.911072945331924, 6.831963940515532, 5.84),
            (46.911131400832886, 6.832166081745054, 5.96),
            (46.91114623412944, 6.83237201734659, 3.87),
            (46.911179801845115, 6.832554144534677, 5.74),
            (46.911239247141665, 6.832770345743802, 5.54),
            (46.911332153505036, 6.832920003503043, 5.66),
            (46.911469994565266, 6.833000285854102, 4.88),
            (46.91155413734386, 6.833126839623345, 4.66),
            (46.91166467580982, 6.833187375580344, 4.82),
            (46.91175221530727, 6.833261994543462, 4.52),
            (46.91178363808408, 6.833434125332751, 4.96),
            (46.911797809959424, 6.833654709890346, 5.41),
            (46.91176983124331, 6.833922527378039, 5.78),
            (46.91175326439586, 6.834195220868793, 6.04),
            (46.91178662839349, 6.8344655677591195, 6.42),
            (46.91178939329174, 6.8347297133566824, 6.07),
            (46.91178277414741, 6.834981734751567, 6.24),
            (46.9117702540272, 6.835228703554163, 6.54),
            (46.91176338990526, 6.835461284250946, 5.61),
            (46.91179936537974, 6.8356849831215785, 5.47),
            (46.91188745154715, 6.835861619756453, 5.37),
            (46.911991158581976, 6.836033506543246, 5.42),
            (46.91206153947409, 6.836238438812386, 5.81),
            (46.91210639411717, 6.836460495078259, 6.31),
            (46.91211610803036, 6.83669527149053, 5.81),
            (46.91211062873277, 6.836932214591168, 6.25),
            (46.91211750000457, 6.837177431282541, 6.4),
            (46.91218136061646, 6.8373953306809145, 5.54),
            (46.91224536111694, 6.837611068924017, 5.62),
            (46.912318787245994, 6.837810137712334, 5.59),
            (46.912405442266966, 6.8379954649135275, 5.94),
            (46.91246736424147, 6.838200577213031, 5.7),
            (46.91248252917609, 6.838433625889243, 6.18),
            (46.912518766718975, 6.838673569581533, 6.41),
            (46.91256019501006, 6.838892466789662, 5.66),
            (46.9125132310509, 6.8391036762456014, 5.41),
            (46.91249283247398, 6.839293358891672, 4.64),
            (46.91250941325912, 6.839503408993135, 5.59),
            (46.9125775571824, 6.839675230946457, 5.72),
            (46.91268278871991, 6.839840839785297, 7.23),
            (46.91276028462621, 6.840040784216195, 6.11),
            (46.912794687494326, 6.84026828263495, 6.35),
            (46.91284429060315, 6.840513497808407, 6.89),
            (46.912901370944965, 6.84073961048346, 5.38),
            (46.91295332925618, 6.840958284983642, 6.33),
            (46.91300052841324, 6.841188006388863, 6.26),
            (46.913003822253536, 6.841421437874633, 5.85),
            (46.913008257177765, 6.841664258238897, 6.48),
            (46.91303620769885, 6.841891041673952, 5.08),
            (46.91307192614064, 6.842092295550824, 1.97),
            (46.913096169213155, 6.842227218781428, 1.46),
            (46.913132952217296, 6.842475156500883, 5.79),
            (46.91315736684237, 6.842738474075082, 6.14),
            (46.91317797193299, 6.8430114489884435, 6.17),
            (46.9131782832634, 6.8432697334552435, 6.01),
            (46.913177085466856, 6.843509279938386, 5.97),
            (46.913175463826995, 6.843735491205206, 5.8),
            (46.91315564218024, 6.84394221514277, 6.17),
            (46.91317502760112, 6.84412658731993, 5.69),
            (46.91323490229001, 6.844304626220303, 5.95),
            (46.913365906703675, 6.844427136184722, 6.63),
            (46.91354374594328, 6.844425213775008, 5.75),
            (46.91367700991426, 6.844506752265416, 6.37),
            (46.91374621014039, 6.8446770767076135, 5.94),
            (46.91378913544377, 6.84486332385616, 5.26),
            (46.91388726867648, 6.844962565047029, 5.5),
            (46.913964137208154, 6.845136266079608, 6.4),
            (46.91401425088272, 6.845354575300087, 6.56),
            (46.914023794225415, 6.845602939437931, 5.42),
            (46.91398770967861, 6.845852946115517, 6.16),
            (46.91394706020041, 6.846107874208598, 6.15),
            (46.91390447566543, 6.846348330036452, 6.06),
            (46.91389644276081, 6.846568454932381, 4.91),
            (46.91393052273343, 6.846780149164588, 5.14),
            (46.91393633168047, 6.846988548395241, 5.35),
            (46.914004226981895, 6.847196137847946, 5.34),
            (46.91406287077487, 6.847402742162862, 6.07),
            (46.91412646323315, 6.847617179751548, 5.6),
            (46.914225972767355, 6.847751168494581, 4.99),
            (46.91435686061712, 6.847821659494524, 5.95),
            (46.914426180040806, 6.847970781128066, 5.15),
            (46.91447569878685, 6.848157606311986, 5.55),
            (46.914500258007635, 6.848352469814165, 4.5),
            (46.91458374478051, 6.848481273216527, 5.12),
            (46.91463084145032, 6.848662706373123, 5.29),
            (46.914678787992315, 6.8488541345919565, 6.07),
            (46.91472265700884, 6.849070206819178, 5.99),
            (46.914753846315776, 6.849296625133388, 5.64),
            (46.914772151137704, 6.849490065752658, 2.73),
            (46.91475075869043, 6.849675440495157, 5.68),
            (46.91475409534869, 6.849901964366411, 6.3),
            (46.91478930849412, 6.850129161517226, 5.74),
            (46.9148221310067, 6.850362809240155, 6.26),
            (46.9148574941766, 6.850594258966757, 5.69),
            (46.914873740101385, 6.850825160931838, 5.45),
            (46.91482666865186, 6.851028093193266, 5.69),
            (46.91476754723092, 6.851202135166959, 5.38),
            (46.91476991854286, 6.851415861265416, 6.42),
            (46.914780107237995, 6.851644667693451, 6.0),
            (46.914753721414165, 6.851868864283829, 5.43),
            (46.914750005872925, 6.852057352234392, 1.27),
            (46.91479388876146, 6.852301500616094, 5.72),
            (46.91485044168298, 6.852526784185949, 5.5),
            (46.914922572675586, 6.852722231952849, 5.32),
            (46.91502597239936, 6.85288282088321, 5.43),
            (46.91511308001279, 6.853053795746719, 5.5),
            (46.9151703101742, 6.8532458329788355, 5.47),
            (46.91516428201603, 6.853475840668819, 5.54),
            (46.915111950956856, 6.853703937229257, 6.02),
            (46.915102034186226, 6.853935460567988, 5.58),
            (46.91511608941724, 6.854167124259224, 6.12),
            (46.91514205246424, 6.8544061128208975, 6.03),
            (46.915163666363306, 6.854636259534822, 5.31),
            (46.91521759028147, 6.854828785699691, 5.61),
            (46.915286875043115, 6.855010046644621, 5.11),
            (46.915377557827696, 6.855170814539127, 6.14),
            (46.915463848553586, 6.855361852826488, 6.91),
            (46.91543774504569, 6.8555796390394415, 6.05),
            (46.91536616373528, 6.855794742424028, 5.68),
            (46.915359187797094, 6.8560259934603405, 5.95),
            (46.91533266150959, 6.856247608307434, 5.52),
            (46.91534730891526, 6.856472080619885, 6.41),
            (46.91534243999098, 6.856714583709995, 7.04),
            (46.91531277619964, 6.856961051988063, 6.74),
            (46.91529858433965, 6.85721425143208, 6.0),
            (46.91531324512613, 6.8574632494160825, 6.16),
            (46.91532465570427, 6.857701702413409, 5.54),
            (46.91535674241104, 6.857920324627844, 5.54),
            (46.91541259783319, 6.8580981092199815, 5.67),
            (46.915548517895225, 6.858171669409133, 6.48),
            (46.915613784945684, 6.858345007018766, 6.28),
            (46.915630268090446, 6.858572428984584, 6.71),
            (46.915657638778754, 6.858824889202171, 6.65),
            (46.91567622690408, 6.85909734250129, 6.62),
            (46.91569571067169, 6.85935854453739, 6.27),
            (46.91570666376616, 6.859614368208354, 6.31),
            (46.91569682917265, 6.859862652061267, 6.19),
            (46.91568804247272, 6.8600983270658, 5.65),
            (46.91565715251804, 6.860303160913273, 5.56),
            (46.915611444010686, 6.860512073007419, 6.18),
            (46.915529292450145, 6.860703585702981, 5.24),
            (46.91554419604694, 6.860902211844256, 6.5),
            (46.915608595636215, 6.861088182435384, 4.27),
            (46.91571886658585, 6.861223044642344, 6.81),
            (46.91576718195397, 6.861384967843337, 4.76),
            (46.91581472191385, 6.861596183102215, 6.13),
            (46.91589581733583, 6.86178647916794, 5.43),
            (46.91599833272247, 6.861928242445987, 5.49),
            (46.916143128866146, 6.861992820306859, 5.5),
            (46.9162286847258, 6.862121318574448, 5.63),
            (46.91625416871315, 6.862315840926138, 6.83),
            (46.91629996429947, 6.862540796700918, 5.56),
            (46.91635791929344, 6.86274452361999, 5.45),
            (46.91637002492454, 6.862953475814666, 5.27),
            (46.91639178646146, 6.863158026970692, 6.32),
            (46.9164248941252, 6.863365636605016, 4.88),
            (46.916449954088975, 6.863588029500179, 6.4),
            (46.91644576095875, 6.863820509410497, 6.08),
            (46.91641331637776, 6.864050532098907, 6.25),
            (46.916405321641655, 6.864279305364675, 6.63),
            (46.916472714025694, 6.864472897670502, 5.52),
            (46.916539339163485, 6.864608099225267, 1.55),
            (46.91660376606996, 6.864806986840411, 5.9),
            (46.916665298675106, 6.865068270750852, 6.01),
            (46.916700644186456, 6.865338015896351, 6.11),
            (46.91668698250673, 6.865591003621614, 5.91),
            (46.91668820100787, 6.86581536539515, 5.84),
            (46.91671032394102, 6.866033628383877, 6.87),
            (46.91673518112325, 6.8662737754957845, 6.69),
            (46.916773856629824, 6.8665119456781545, 5.96),
            (46.91680638375547, 6.866766830411117, 6.78),
            (46.91683510220959, 6.8670208061899745, 6.42),
            (46.91687208993017, 6.867248245329762, 4.88),
            (46.91692389599278, 6.867459713006333, 5.58),
            (46.91695985479703, 6.867664291482366, 5.66),
            (46.91706738171234, 6.867831114103633, 6.08),
            (46.91715440081175, 6.868016705821485, 5.95),
            (46.917184048209066, 6.868227903571696, 5.68),
            (46.91724931743058, 6.868424706864212, 5.75),
            (46.91733021000444, 6.8686043062363, 5.62),
            (46.91738166229302, 6.868800186155121, 5.7),
            (46.91746984708446, 6.868979034736631, 6.19),
            (46.91751388068304, 6.869196451010051, 5.82),
            (46.91753558168756, 6.869403396887088, 4.61),
            (46.917625177060586, 6.869532031635741, 7.15),
            (46.917699324457146, 6.8696970976668865, 5.69),
            (46.917767046940114, 6.869885229184896, 6.33),
            (46.917808859476025, 6.8700911901223005, 5.67),
            (46.91782822062314, 6.870317824328795, 6.44),
            (46.91786452341677, 6.8705658147955795, 6.3),
            (46.9179060104007, 6.870811447747916, 6.17),
            (46.91793407270946, 6.871044788626725, 4.16),
            (46.91791154852656, 6.871260519460172, 3.6),
            (46.91793160269696, 6.871458831149681, 6.15),
            (46.91792881388533, 6.871679766496734, 6.09),
            (46.91797736975744, 6.871897811556178, 5.87),
            (46.91806974267478, 6.872083963237621, 5.73),
            (46.918116510887195, 6.872294508488741, 6.23),
            (46.9181383525273, 6.872519128398773, 6.84),
            (46.91820621312496, 6.872672290872408, 5.89),
            (46.9183261068311, 6.87272592929523, 5.62),
            (46.918457762958006, 6.872800614769099, 6.24),
            (46.91855092719187, 6.8729521868533405, 5.7),
            (46.9186112464785, 6.873155462560746, 6.09),
            (46.918666043692276, 6.873375732774857, 5.52),
            (46.9186910467714, 6.873609025576468, 5.92),
            (46.91869201306798, 6.873836583826026, 5.4),
            (46.91867104730741, 6.874065857068107, 5.54),
            (46.91865692382335, 6.87429106430784, 5.93),
            (46.918667101993194, 6.874516463226982, 5.23),
            (46.918727895816886, 6.874659728381097, 6.22),
            (46.91886488069691, 6.874658613565056, 5.41),
            (46.919021167883386, 6.874637647974153, 5.97),
            (46.9191892320611, 6.87466194153325, 5.96),
            (46.91929099038395, 6.874795757790782, 5.89),
            (46.91930697483732, 6.875018898596044, 5.82),
            (46.91932738690269, 6.875254988400447, 5.74),
            (46.9193680587587, 6.875480874723384, 5.02),
            (46.91947052603249, 6.875599546433977, 5.17),
            (46.919585572972046, 6.875662036139483, 6.19),
            (46.91966348059176, 6.8758258988550045, 6.41),
            (46.919708113118894, 6.876031544444294, 5.82),
            (46.91976750011097, 6.876252410583955, 6.18),
            (46.9198374861596, 6.876485218293179, 6.0),
            (46.91986950881074, 6.876717949433005, 6.49),
            (46.91982865568864, 6.876944735350079, 4.83),
            (46.91984719026757, 6.877146395115102, 5.31),
            (46.919945384461506, 6.877249155776304, 6.02),
            (46.92007804411772, 6.877239195994726, 5.55),
            (46.92022781167362, 6.877156389893666, 5.09),
            (46.92037285347232, 6.877097892762524, 5.37),
            (46.92045018358801, 6.877214285153983, 5.07),
            (46.92050875107044, 6.877390576677622, 5.27),
            (46.9205321004003, 6.8775994002073615, 5.34),
            (46.9206201138253, 6.877753690049725, 5.21),
            (46.92068834842289, 6.8779380950677105, 5.6),
            (46.920768534853735, 6.8781194222372966, 5.28),
            (46.92084335493054, 6.8783132592638605, 6.62),
            (46.92088537249509, 6.878531599681323, 5.04),
            (46.920912290939775, 6.878703922477177, 5.1),
            (46.92097259018008, 6.878855508906655, 5.63),
            (46.92106300577963, 6.879005666124917, 5.55),
            (46.92113593145325, 6.879177999091515, 6.28),
            (46.92117532829295, 6.879399015693596, 6.83),
            (46.921225287374504, 6.879637285934292, 6.14),
            (46.92122799045222, 6.879867224219322, 4.94),
            (46.92125838867742, 6.88005963061476, 6.34),
            (46.92130807507185, 6.880234834059825, 6.14),
            (46.92127923347388, 6.880429126340755, 5.59),
            (46.92126289548653, 6.880667154100338, 6.12),
            (46.92128105980924, 6.880889940857856, 5.18),
            (46.92138929843362, 6.881015762525659, 6.02),
            (46.92148008469777, 6.881176395446005, 4.28),
            (46.92159629956507, 6.8812444718427335, 5.13),
            (46.92173943236179, 6.881310440682409, 5.67),
            (46.92180490454282, 6.881506806345721, 6.24),
            (46.92183466943439, 6.881740349855633, 6.54),
            (46.92181227834656, 6.881992548964856, 5.44),
            (46.92178711229243, 6.882233060009485, 6.23),
            (46.921813039099014, 6.882467644318913, 5.65),
            (46.921895325573324, 6.882619090625565, 6.62),
            (46.921970744402984, 6.882766917283129, 6.35),
            (46.92198255083294, 6.882938895315948, 4.79),
            (46.92199804236262, 6.883117022339296, 5.26),
            (46.922067357663956, 6.883271470767792, 5.64),
            (46.922121919437785, 6.883456966988431, 5.6),
            (46.92215764221278, 6.883658961961331, 5.41),
            (46.92212933886408, 6.883865906680448, 6.19),
            (46.92213477141355, 6.884110026108193, 6.59),
            (46.92219034169276, 6.884325962892271, 6.31),
            (46.92227265594357, 6.884518002065592, 5.74),
            (46.92231722102446, 6.884715130717361, 6.01),
            (46.92237616172339, 6.884930195602909, 6.53),
            (46.92243604733667, 6.88515524235613, 6.15),
            (46.92248558604075, 6.885389258864448, 6.54),
            (46.92250270076899, 6.885617444754168, 5.65),
            (46.92255492522465, 6.8857940792974235, 4.12),
            (46.92264464589604, 6.885932149356246, 5.6),
            (46.922759569983704, 6.88605689869383, 6.72),
            (46.92282929549311, 6.886241574849533, 5.61),
            (46.922829132720736, 6.886440069140861, 5.5),
            (46.92285011966424, 6.886637609254437, 5.19),
            (46.922953995425964, 6.886717465628934, 4.69),
            (46.923099141419456, 6.886728555401079, 5.61),
            (46.92321302778461, 6.8868252856052985, 6.1),
            (46.92324736895773, 6.887000764417742, 5.66),
            (46.92322678960659, 6.887196587794749, 5.76),
            (46.92324934726636, 6.887430505852422, 5.5),
            (46.923300244861856, 6.8875877026729855, 2.83),
            (46.92341700634877, 6.88768253527138, 6.25),
            (46.92356360306225, 6.887769776240357, 5.57),
            (46.923733301425365, 6.887794110032927, 5.53),
            (46.923901835384555, 6.8878277485764805, 5.5),
            (46.92401195368291, 6.887937778200332, 5.06),
            (46.924073510996294, 6.888120052762871, 4.82),
            (46.92410403723837, 6.888345935685658, 6.23),
            (46.92411376964474, 6.888596660370057, 6.44),
            (46.924161077545506, 6.88882934905292, 5.86),
            (46.92428097194721, 6.888941418161574, 5.82),
            (46.924410940897204, 6.88903598301461, 5.22),
            (46.92453489047475, 6.889133031357324, 5.89),
            (46.92462305699477, 6.88927565877051, 4.8),
            (46.92469935096246, 6.889435348810545, 5.07),
            (46.92480168665585, 6.889567986966396, 5.26),
            (46.924859596345385, 6.889745991439691, 6.23),
            (46.92488366172956, 6.889969598774483, 5.09),
            (46.92490373642195, 6.8901816414337445, 4.98),
            (46.92492448448696, 6.890396893659089, 5.79),
            (46.92498273272082, 6.890589647998735, 5.72),
            (46.92507024656108, 6.89073713302675, 3.76),
            (46.92518966583033, 6.890772325428744, 5.39),
            (46.92530836945368, 6.8908203700127695, 6.64),
            (46.92534248276978, 6.890987695884953, 5.61),
            (46.925328015209764, 6.891206054930663, 5.17),
            (46.92531570743871, 6.891428153124681, 6.0),
            (46.925340388846145, 6.891659983519068, 6.23),
            (46.92541743553707, 6.891861679819096, 6.65),
            (46.92552078878033, 6.892018719949397, 5.29),
            (46.9255919483227, 6.892186838391606, 6.01),
            (46.925584122837236, 6.8924147069952495, 6.76),
            (46.92554418723569, 6.89263578990427, 5.19),
            (46.92557447211946, 6.892799754584384, 5.43),
            (46.925695950943464, 6.892792534134698, 5.83),
            (46.92585414333025, 6.892752438444994, 5.39),
            (46.92602174898942, 6.892703267908615, 5.86),
            (46.92618222164749, 6.892657466856144, 4.79),
            (46.926336175849045, 6.892689665825744, 6.13),
            (46.92647919766396, 6.892753285836828, 5.71),
            (46.92662077937032, 6.892865548993248, 5.8),
            (46.92675453401219, 6.892959364398165, 5.05),
            (46.926894708118986, 6.893034039196118, 5.42),
            (46.92699762548253, 6.89317031215273, 5.37),
            (46.927075529981046, 6.89331392306632, 4.55),
            (46.927185255941794, 6.893396318939698, 5.99),
            (46.92731734757409, 6.893402845733761, 4.63),
            (46.92745072699812, 6.893456403646002, 6.2),
            (46.927521011000024, 6.893597653457474, 5.21),
            (46.92755487810798, 6.893771025545372, 5.72),
            (46.92751155416656, 6.8939609876258325, 5.34),
            (46.92748008732512, 6.894147744301718, 5.32),
            (46.927527832051275, 6.894314646972119, 4.73),
            (46.927562473127736, 6.894484321061098, 4.55),
            (46.927620225985244, 6.894653858747775, 6.39),
            (46.927709254050505, 6.894805512482538, 6.6),
            (46.92782398579908, 6.894912951372819, 5.15),
            (46.92794717368283, 6.895008433106773, 6.31),
            (46.92808039003674, 6.8950856390914765, 5.61),
            (46.92810787923065, 6.8952376048268915, 4.91),
            (46.9281033225945, 6.895438059813759, 5.56),
            (46.92809533502527, 6.8956547703406725, 4.88),
            (46.928142315325346, 6.895843197860566, 5.17),
            (46.92825619960553, 6.895947657510623, 6.82),
            (46.92836353890737, 6.896062907585664, 6.28),
            (46.92846326553279, 6.896193252943283, 5.04),
            (46.92854657197964, 6.896335070491663, 5.12),
            (46.92865430302731, 6.896414543641014, 3.92),
            (46.92876528354791, 6.896518391424347, 5.69),
            (46.92889954260532, 6.896615035960262, 5.45),
            (46.92898420238074, 6.896773650760815, 5.7),
            (46.92905823047953, 6.896972562239739, 6.58),
            (46.92915095129099, 6.89713658321897, 6.02),
            (46.929281473812466, 6.8972031124773, 5.08),
            (46.92939334165346, 6.897262556661335, 6.01),
            (46.92942863117176, 6.897420929917101, 5.28),
            (46.92942435241027, 6.897619128557127, 5.59),
            (46.92937666725976, 6.897849753082024, 6.17),
            (46.92934450764289, 6.898105105729725, 6.05),
            (46.929357117262775, 6.898330024027722, 5.4),
            (46.92944158913685, 6.898493089263504, 5.15),
            (46.929584272013294, 6.89856530441796, 5.74),
            (46.92975754919351, 6.898589625277471, 6.0),
            (46.929933250523256, 6.8986158733233784, 5.44),
            (46.93010465339833, 6.8986124046276265, 5.97),
            (46.93025620273582, 6.8986671968008, 6.07),
            (46.93036666752959, 6.8987428510419555, 2.28),
            (46.93039637761463, 6.898746736073251, 2.67),
            (46.93039403228837, 6.8987450218215445, 0.17),
            (46.930370525134244, 6.898767917325873, 2.76),
            (46.93036223499425, 6.898815263046928, 1.28),
            (46.93036726487325, 6.898818052156817, 0.43),
            (46.9303714264131, 6.898806968837946, 0.26),
            (46.93036834477801, 6.8988000498261455, 0.54),
            (46.93036647600465, 6.89880123334079, 0.25),
            (46.93036707074832, 6.898797978469642, 0.37),
            (46.93037211370986, 6.8988006438674105, 0.52),
            (46.930377931064186, 6.898815154711563, 0.09),
            (46.93038175150349, 6.89883204947652, 0.57),
            (46.930386410790454, 6.898853378363383, 0.54),
            (46.93039410442525, 6.8988649087787906, 0.25),
            (46.93039782346487, 6.8988793482005555, 1.36),
            (46.9304035067489, 6.898915291183023, 1.37),
            (46.9303953086366, 6.898978240380346, 1.8),
            (46.93036804753412, 6.899049991842357, 2.11),
            (46.930331473740765, 6.89912018178874, 2.32),
            (46.93029170701251, 6.89919223542781, 2.11),
            (46.93024807319174, 6.8992680392848476, 1.49),
            (46.93021468351476, 6.899339648215065, 1.94),
            (46.930190350680526, 6.899414602684006, 2.39),
            (46.930162719077295, 6.899525292723475, 4.73),
            (46.93009056190825, 6.8996617630160815, 5.08),
            (46.92995110042629, 6.89974966359582, 6.21),
            (46.92977482633359, 6.899776107141662, 5.98),
            (46.9295890194751, 6.899776776218584, 5.8),
            (46.92941769327251, 6.899746862814818, 5.35),
            (46.929256408697, 6.899719888618911, 5.61),
            (46.92910702166983, 6.899694771368408, 5.53),
            (46.92896235364776, 6.899658412598944, 5.03),
            (46.928823854771366, 6.8996454495320725, 5.54),
            (46.92868791342875, 6.899640659129916, 4.75),
            (46.928581883600344, 6.899709433589926, 5.08),
            (46.928593761728024, 6.899850861363865, 4.56),
            (46.92871563434942, 6.899877306695685, 5.89),
            (46.92888208751296, 6.89980375953418, 5.33),
            (46.9290403828662, 6.899673633886548, 5.41),
            (46.929174472171375, 6.899491078912012, 5.69),
            (46.929283976500464, 6.899269953299942, 6.21),
            (46.92936966755598, 6.899037537449974, 5.65),
            (46.92944127322686, 6.898819342616748, 5.42),
            (46.92951766652672, 6.898627809578651, 5.1),
            (46.92960635147574, 6.898464343093431, 5.72),
            (46.929696777178656, 6.898299689112479, 5.44),
            (46.92979443677869, 6.898137833143436, 5.75),
            (46.92989109942614, 6.897965957235668, 5.62),
            (46.92997851481093, 6.897789854644994, 5.57),
            (46.93006371221314, 6.897609075610005, 5.29),
            (46.93014803208194, 6.897444498243496, 4.98),
            (46.93023139207198, 6.897293400392923, 4.54),
            (46.930324067027165, 6.897152488165271, 5.48),
            (46.93043980962266, 6.897021393758464, 5.86),
            (46.93056048830852, 6.896872302268369, 5.89),
            (46.930682820055104, 6.896710827548178, 5.98),
            (46.93081184884982, 6.896548937941626, 6.46),
            (46.93094606164293, 6.896374305440861, 6.8),
            (46.93107412317787, 6.896177355686041, 6.81),
            (46.931193782252386, 6.895981183211624, 6.18),
            (46.931318993649946, 6.895805402224021, 6.57),
            (46.931441435668575, 6.895617350664563, 6.6),
            (46.93156109668684, 6.895422229053061, 6.66),
            (46.93166177944979, 6.895216518887609, 6.09),
            (46.9317545523103, 6.895018177112142, 5.84),
            (46.9318402565708, 6.894827711049131, 5.64),
            (46.931920583301014, 6.894642611993902, 5.61),
            (46.93201908785636, 6.894472692890081, 6.09),
            (46.93213163074854, 6.894304152223515, 6.06),
            (46.932241038106916, 6.8941213684452425, 6.22),
            (46.93235514354119, 6.893938652091332, 6.5),
            (46.93247556514281, 6.89375424839074, 6.26),
            (46.93258680303497, 6.893571959130061, 5.91),
            (46.93269591239012, 6.893399338873647, 5.74),
            (46.932802913730555, 6.8932267542166565, 6.07),
            (46.93290457880101, 6.893054576865107, 5.78),
            (46.9330096322586, 6.892900476974209, 6.2),
            (46.93312545360274, 6.892744592663376, 5.88),
            (46.933254038764105, 6.892593867833785, 6.77),
            (46.933380773782034, 6.89242074594748, 6.18),
            (46.93349344371322, 6.8922428899413415, 5.83),
            (46.93360758880979, 6.892078751716107, 5.71),
            (46.93371709739481, 6.891924985150677, 5.38),
            (46.933827189099794, 6.891778519504748, 5.74),
            (46.933935828777315, 6.891628765663151, 5.86),
            (46.93403378048893, 6.891459847201646, 5.64),
            (46.934125091266104, 6.891287715190197, 5.4),
            (46.93421960034633, 6.89112073866472, 5.11),
            (46.93434313408731, 6.891014270324939, 6.49),
            (46.934503923886226, 6.891035076855107, 6.36),
            (46.93465655429381, 6.8910016755279315, 4.84),
            (46.934798182595095, 6.890975726859374, 5.5),
            (46.93494317516511, 6.891019764313769, 5.44),
            (46.93504286916119, 6.891166174815657, 5.67),
            (46.93507276006909, 6.891388006650504, 4.98),
            (46.93510136252846, 6.8916291085074715, 5.8),
            (46.9350940291522, 6.891888026609672, 5.48),
            (46.935128586200236, 6.892112222351411, 5.37),
            (46.935176328145154, 6.892293108515218, 5.73),
            (46.93529317105868, 6.892491681947601, 6.1),
            (46.93544702508056, 6.892587289205428, 6.09),
            (46.93561982698656, 6.892621750188151, 5.53),
            (46.93578655602232, 6.892595087420695, 5.26),
            (46.93592454035325, 6.892551927600971, 4.74),
            (46.93605617300019, 6.892476216167463, 5.7),
            (46.936204940444355, 6.892412004539508, 5.56),
            (46.936352804132525, 6.892394991545151, 5.29),
            (46.936499930862354, 6.892370492198375, 5.47),
            (46.936643790542064, 6.892321806830102, 6.0),
            (46.93679491942046, 6.892297119947439, 6.08),
            (46.93695632633084, 6.892326426127229, 6.13),
            (46.937120705848606, 6.89234140379718, 5.59),
            (46.93727564824221, 6.8923832128454565, 5.64),
            (46.93742127176883, 6.892440948202018, 5.02),
            (46.93754949415651, 6.892545385161571, 5.92),
            (46.93765346865964, 6.892705190921138, 5.16),
            (46.93775613616649, 6.892852847807233, 6.02),
            (46.937827056889894, 6.893015970566219, 4.77),
            (46.93789047870553, 6.89318546537073, 6.34),
            (46.93790844990922, 6.893416297855841, 6.68),
            (46.937926906710835, 6.8936804834544, 6.31),
            (46.93796646149966, 6.893938148547786, 6.42),
            (46.93800532988404, 6.8941897756596635, 6.42),
            (46.93806633752471, 6.894428236820078, 6.03),
            (46.93812571849717, 6.894633306596507, 5.23),
            (46.93824818157394, 6.8947548728226735, 5.45),
            (46.93839606515883, 6.894804016036289, 5.73),
            (46.93856600107098, 6.894786214093048, 5.48),
            (46.93873793311247, 6.894754262897839, 5.79),
            (46.93891378181677, 6.894672133672272, 6.08),
            (46.93908178467322, 6.894640394205749, 6.14),
            (46.93925436724276, 6.894665662854126, 6.66),
            (46.93942515893426, 6.8947173321152935, 5.62),
            (46.93958077293106, 6.894761555260518, 5.36),
            (46.93968419838885, 6.89493128183834, 6.69),
            (46.93970059039058, 6.895178270271605, 5.67),
            (46.9396512331497, 6.895439493543495, 5.69),
            (46.93960032436638, 6.895703017138115, 5.77),
            (46.93955865766182, 6.895952586142965, 4.47),
            (46.93956246817495, 6.896165297668904, 3.85),
            (46.9396616838654, 6.896255816720721, 5.91),
            (46.939837047307556, 6.89626823178859, 6.42),
            (46.93999406554269, 6.896292119873547, 5.01),
            (46.94013935168824, 6.896348948628863, 5.63),
            (46.94029986318582, 6.896387241475652, 5.51),
            (46.940426120486414, 6.896480255747405, 4.91),
            (46.94050678134268, 6.896643757374716, 5.67),
            (46.94057578427382, 6.89678981659235, 4.1),
            (46.94065813951633, 6.89694614615957, 5.27),
            (46.94077870770301, 6.897052271784158, 5.54),
            (46.940929998931615, 6.897064412729437, 6.49),
            (46.94109276359019, 6.897090953476624, 6.47),
            (46.94125264096005, 6.89711524152601, 6.44),
            (46.94142235070611, 6.897127554170417, 6.89),
            (46.941567883592654, 6.897223641593872, 5.16),
            (46.9416857219613, 6.897345796934507, 5.92),
            (46.941808950123914, 6.897461226554898, 4.54),
            (46.941934126648334, 6.8975548820813595, 5.33),
            (46.94208555373458, 6.897525722614243, 6.57),
            (46.94224447920313, 6.89750946316889, 6.06),
            (46.942358434590126, 6.897615512105864, 5.68),
            (46.9424180299644, 6.897717018807277, 1.43),
            (46.942449005364026, 6.8977596477964305, 1.45),
            (46.94242161289011, 6.897782103224136, 0.71),
            (46.94239268412443, 6.897793846315885, 0.78),
            (46.94239541383932, 6.897805531778249, 2.49),
            (46.94238575744791, 6.897799303045551, 0.3),
            (46.942369685850274, 6.897790713658608, 0.18),
            (46.94236592514874, 6.897785341335209, 0.24),
            (46.942369124647996, 6.897785821920863, 0.12),
            (46.94237731609004, 6.897792473204436, 0.05),
            (46.942383982007456, 6.89780412427604, 0.43),
            (46.942387467381856, 6.897818407417435, 0.34),
            (46.9423892932913, 6.8978311407998305, 0.19),
            (46.942394478609614, 6.897844537764686, 0.6),
            (46.94239863443954, 6.897852379145324, 0.41),
            (46.9424016284174, 6.8978609731296805, 0.06),
            (46.94240590844921, 6.8978668444141995, 0.7),
            (46.94241608464311, 6.897874666243505, 0.33),
            (46.94242172743065, 6.897878364991276, 0.52),
            (46.94242122983305, 6.897882263139531, 0.61),
            (46.94242449316021, 6.897897962366322, 0.17),
            (46.9424314893646, 6.897908841215065, 0.66),
            (46.94244571597842, 6.897927958274094, 0.81),
            (46.94245873841536, 6.897962751844301, 1.24),
            (46.942456786733885, 6.898011939555009, 1.2),
            (46.94243832452898, 6.898075590434651, 1.84),
            (46.94240721097085, 6.898153132398926, 2.08),
            (46.94237978365668, 6.898241649501799, 2.46),
            (46.942358041333456, 6.898349138905913, 1.7),
            (46.942320762691686, 6.8984651923473495, 4.65),
            (46.942252209224144, 6.898629974827906, 5.68),
            (46.94216959528211, 6.898821689664208, 5.32),
            (46.942064775813826, 6.898999604617514, 4.73),
            (46.941994219164876, 6.899191683136891, 6.58),
            (46.94198648283376, 6.899446621242386, 6.12),
            (46.94208970173082, 6.8995716606444155, 6.54),
            (46.942250161524946, 6.899547554072605, 5.87),
            (46.94241989812715, 6.899540699294121, 5.31),
            (46.94257487108393, 6.8995797261407965, 5.03),
            (46.94272954752264, 6.899632079367588, 5.23),
            (46.94285946375891, 6.8997189981542455, 5.3),
            (46.942995751249256, 6.899775574376248, 6.41),
            (46.94314726016252, 6.899784700303046, 6.32),
            (46.94330239301589, 6.89982005141158, 5.53),
            (46.943450569071686, 6.8997971458061444, 5.52),
            (46.9436006927572, 6.899732242158261, 6.27),
            (46.94375302908201, 6.899717238931929, 6.02),
            (46.94389737402118, 6.899756135667893, 6.36),
            (46.944049682241676, 6.899831646924213, 6.07),
            (46.944203728852536, 6.899828211279695, 5.63),
            (46.94435172635794, 6.899841638974162, 5.5),
            (46.944505192132375, 6.899820109417538, 4.87),
            (46.944630995501036, 6.899895400876193, 6.09),
            (46.94475386919305, 6.90000557656769, 5.78),
            (46.94485171516276, 6.900170543136272, 5.11),
            (46.94495811515022, 6.90031753722231, 5.07),
            (46.94508262121985, 6.900388388593087, 5.22),
            (46.94522829304462, 6.900459107905034, 5.73),
            (46.94537505202768, 6.9004650469971285, 5.56),
            (46.94552242788312, 6.900373384188906, 5.96),
            (46.94567852496775, 6.900319566707056, 6.2),
            (46.94583734064969, 6.900298732014821, 5.54),
            (46.94597996240971, 6.900344873302914, 5.45),
            (46.94612680642248, 6.900413121123538, 6.34),
            (46.94627760741268, 6.900513256743323, 6.11),
            (46.946424990443084, 6.9005848659120215, 5.71),
            (46.94657336700351, 6.900668175941888, 5.78),
            (46.946714570295846, 6.900769369275777, 5.67),
            (46.946839584501944, 6.900874180875053, 4.73),
            (46.94696179354602, 6.900983794910434, 5.41),
            (46.9470849874528, 6.901091150082944, 5.53),
            (46.94721099532063, 6.9011698745381995, 5.02),
            (46.94736598496717, 6.901232164964732, 6.99),
            (46.94750166934881, 6.901359044853509, 6.79),
            (46.94760556667751, 6.901473575415167, 5.83),
            (46.94773928383408, 6.901522780454778, 6.27),
            (46.94786934841548, 6.901599997159595, 5.56),
            (46.947998584873496, 6.901642914618873, 5.42),
            (46.948097878137936, 6.9017547688718555, 6.54),
            (46.94818664836743, 6.90188374679399, 6.71),
            (46.948295958179465, 6.902035935979881, 6.56),
            (46.94839071985727, 6.90221728740636, 5.68),
            (46.94846652123334, 6.9024276842011165, 5.96),
            (46.9485336790254, 6.902626292938205, 7.11),
            (46.948632351707154, 6.902782907663759, 5.02),
            (46.94874364900961, 6.902899544451632, 6.06),
            (46.94884452665124, 6.903038725248687, 6.15),
            (46.948927359412444, 6.903208955372274, 5.52),
            (46.949009588402646, 6.903361907755295, 5.7),
            (46.94907801735152, 6.9034972974684115, 5.18),
            (46.94918531390658, 6.903529308578658, 5.3),
            (46.94932536745579, 6.9034980992564545, 6.35),
            (46.94948033724139, 6.903514272290852, 5.81),
            (46.949629420069215, 6.903603053958187, 6.12),
            (46.949784112406235, 6.903697202012684, 6.09),
            (46.949944940400776, 6.903759352485419, 5.72),
            (46.95005375883721, 6.903853015901424, 6.08),
            (46.950117263699816, 6.90397650732347, 5.05),
            (46.950199491204195, 6.904100963332243, 5.27),
            (46.95026965890564, 6.904248259027657, 5.08),
            (46.9503796432977, 6.90435174870988, 5.89),
            (46.95050664855171, 6.904421270614465, 5.07),
            (46.95065325503269, 6.904435166702237, 5.91),
            (46.95080918481525, 6.9044341563454505, 5.49),
            (46.950954223740744, 6.904484436598683, 5.39),
            (46.951052461352326, 6.904630388522055, 5.56),
            (46.95110809440551, 6.904808661277563, 5.66),
            (46.9511676336848, 6.904996254544469, 5.45),
            (46.95123461957914, 6.905145944521479, 5.06),
            (46.95131229397343, 6.905299701144415, 5.57),
            (46.9513658367432, 6.905471794440679, 5.18),
            (46.95142871416, 6.905647045753924, 4.65),
            (46.95153035100459, 6.905771374661547, 5.24),
            (46.951635321075315, 6.905914342880131, 5.36),
            (46.9517209265113, 6.906085522412686, 5.7),
            (46.95182125151017, 6.906244396640727, 7.45),
            (46.95191543442127, 6.9063895594538955, 5.31),
            (46.95203435260551, 6.906532511332764, 6.08),
            (46.95214508673367, 6.906667546930531, 4.75),
            (46.95228651670516, 6.906689118614212, 5.23),
            (46.95244494688722, 6.906693125419314, 5.99),
            (46.95261104166361, 6.906691950089426, 6.64),
            (46.95277874869463, 6.9066272104914175, 6.29),
            (46.952928490262785, 6.906629002508337, 5.29),
            (46.953047427107904, 6.906697022873505, 3.78),
            (46.95313249502012, 6.906809247695382, 4.63),
            (46.953186129279196, 6.907001076908933, 5.23),
            (46.953256310009316, 6.907181319593557, 4.59),
            (46.95331755775122, 6.907363911726385, 5.52),
            (46.95335034229708, 6.9075819245618275, 6.15),
            (46.95334897382437, 6.907808712271452, 5.0),
            (46.953400812636325, 6.9079851116318345, 4.9),
            (46.95344357522883, 6.9081707616683, 5.55),
            (46.95351077506594, 6.908343528994083, 5.21),
            (46.953577847825805, 6.908513632172629, 5.1),
            (46.95362780110561, 6.908715205786759, 5.55),
            (46.95366206208659, 6.908915496707549, 5.49),
            (46.953722459642584, 6.90908865976182, 4.94),
            (46.95383291373875, 6.909166175941471, 5.66),
            (46.953976479103325, 6.909224231533009, 5.42),
            (46.95413699325024, 6.909227680703381, 6.32),
            (46.954221703298025, 6.909335988667484, 5.78),
            (46.95419553342107, 6.909494035425019, 6.13),
            (46.95425133140003, 6.909658477661876, 5.24),
            (46.954368550026565, 6.90976260355653, 5.54),
            (46.954527150447234, 6.909828415591223, 6.11),
            (46.954685595601795, 6.909904938033852, 5.72),
            (46.9547976905941, 6.910073547756215, 6.33),
            (46.95485775375467, 6.9102907931544015, 6.14),
            (46.954909626313416, 6.910541807718641, 6.59),
            (46.95492428877671, 6.910805858753083, 5.99),
            (46.95495781603526, 6.911050956746933, 5.97),
            (46.95502632181045, 6.911273623387269, 6.74),
            (46.95505961777891, 6.911524503262201, 6.06),
            (46.95505494741213, 6.911748956518254, 5.7),
            (46.95505079602907, 6.911924863251811, 4.51),
            (46.95513721379392, 6.911986039754355, 4.83),
            (46.955273303471024, 6.912011719603042, 5.73),
            (46.9554126573056, 6.9120394364903746, 5.72),
            (46.95551161655502, 6.912178182670303, 4.76),
            (46.95558547161839, 6.912371801420711, 5.29),
            (46.95563402656486, 6.912610497462835, 6.02),
            (46.955696994946194, 6.912834966537833, 5.65),
            (46.955744044506865, 6.913077405734351, 6.12),
            (46.9558419410823, 6.9132546406139115, 5.49),
            (46.955964048747354, 6.913376644354488, 5.38),
            (46.95610274335273, 6.913465618765703, 7.54),
            (46.95620142665378, 6.913632519753657, 6.14),
            (46.95629543888266, 6.913799600741873, 6.09),
            (46.95639826733064, 6.913921107337886, 4.86),
            (46.95648110099368, 6.91407933183377, 5.41),
            (46.956545345965985, 6.914267121860787, 6.13),
            (46.95655679428133, 6.914485745200649, 6.29),
            (46.95660983794581, 6.914734830517806, 6.76),
            (46.956637533632566, 6.914956267757271, 5.85),
            (46.95668397989484, 6.915148492370026, 4.76),
            (46.9567311369647, 6.9153177033841775, 3.78),
            (46.95684022451759, 6.915430105304481, 5.88),
            (46.956879069098086, 6.915608131570648, 5.09),
            (46.9569026582197, 6.915772430611879, 2.8),
            (46.95694777884167, 6.915920918167684, 6.6),
            (46.95703389155085, 6.916145338358472, 5.6),
            (46.95712690685823, 6.916358965690623, 5.2),
            (46.957190271197, 6.916573391600988, 5.94),
            (46.95722373848501, 6.916789553973061, 4.97),
            (46.95728306755698, 6.916966246794994, 4.71),
            (46.95741220487521, 6.9170025692004895, 6.5),
            (46.9575776826139, 6.916967858203813, 5.7),
            (46.95772416116132, 6.916951501345428, 4.44),
            (46.9578445555067, 6.917003120185553, 5.55),
            (46.957976709328705, 6.917100828787555, 5.77),
            (46.95811868339313, 6.917209461875788, 5.61),
            (46.95821184192046, 6.91737925136317, 5.37),
            (46.95823624081988, 6.917581359999412, 5.05),
            (46.95823673228284, 6.9178036535101235, 5.42),
            (46.95821077703836, 6.918034900450309, 4.68),
            (46.95823166083966, 6.918234507864406, 5.28),
            (46.95827461391267, 6.918415564017279, 6.11),
            (46.95833041251807, 6.918619239980087, 5.32),
            (46.9583609177303, 6.918817647353921, 4.47),
            (46.95839316809294, 6.919007498130019, 3.71),
            (46.95838359029236, 6.919212663507241, 5.72),
            (46.958381076932525, 6.919435523997526, 5.46),
            (46.958466106970796, 6.919575135389702, 4.68),
            (46.95856923010884, 6.919738656522589, 5.66),
            (46.95866102889141, 6.91984507133889, 4.8),
            (46.95874427976759, 6.91997335343113, 4.96),
            (46.95885635786892, 6.9200675076548235, 5.9),
            (46.958971514926745, 6.920164413178385, 5.3),
            (46.95904046668259, 6.920317506064774, 6.24),
            (46.959048004621465, 6.92050666922875, 5.38),
            (46.95904353534142, 6.9207327405490835, 6.42),
            (46.95911068283389, 6.920919371655023, 6.66),
            (46.95925274458286, 6.920978119655473, 5.39),
            (46.95936728654709, 6.921082910461437, 4.07),
            (46.95946223122693, 6.92117776294724, 5.2),
            (46.959585860320885, 6.92126766049171, 5.34),
            (46.95970875101707, 6.921346923830431, 3.83),
            (46.959823717525, 6.92143931701419, 6.27),
            (46.9599560132753, 6.921521415516238, 5.44),
            (46.96008989723242, 6.921538833872871, 5.74),
            (46.960239767975985, 6.9215651832459955, 6.73),
            (46.96037952389463, 6.921691110129871, 6.11),
            (46.96051322916521, 6.9218292879055845, 6.25),
            (46.96066500847112, 6.921877622106003, 5.76),
            (46.96082032043041, 6.921925893221603, 5.73),
            (46.96096120757053, 6.922000079536637, 5.88),
            (46.961097081719295, 6.9220905618181785, 5.75),
            (46.96123016742473, 6.922148812322547, 7.41),
            (46.96135143425475, 6.922214485182871, 6.68),
            (46.9614801884722, 6.922321946153279, 5.67),
            (46.96155701612392, 6.92249563133446, 4.89),
            (46.96163849701701, 6.922672309775718, 8.16),
            (46.96169149734785, 6.922860468038237, 6.21),
            (46.96174935422731, 6.9230796144511055, 5.97),
            (46.96185351819184, 6.923221508995496, 5.62),
            (46.961956229814874, 6.9233116559933165, 5.71),
            (46.9620816137665, 6.923431199449951, 6.71),
            (46.96222119446136, 6.923545400478591, 5.21),
            (46.96237778325927, 6.923557322846291, 6.12),
            (46.96252866709554, 6.923557830886426, 3.07),
            (46.9626306099439, 6.923644363419019, 5.73),
            (46.962692934339735, 6.923804956195542, 5.1),
            (46.96272171951001, 6.92399572188437, 1.41),
            (46.962712263101864, 6.924166952152934, 3.22),
            (46.962727810770986, 6.924399138494009, 5.57),
            (46.96279287839816, 6.924595643049361, 5.57),
            (46.9629111269722, 6.924714812773307, 4.72),
            (46.96305687603912, 6.924808506735527, 6.54),
            (46.963149256883995, 6.924964350472719, 3.19),
            (46.963271640420984, 6.925077851024212, 6.5),
            (46.96340453721883, 6.925204579728532, 5.84),
            (46.96352508234778, 6.925360418786021, 6.7),
            (46.963647479828175, 6.925514693168718, 5.63),
            (46.963715694998214, 6.925710537169644, 5.5),
            (46.96376601808844, 6.925894835639131, 5.01),
            (46.96388502248352, 6.925971085468887, 5.44),
            (46.96400283007285, 6.926047058737527, 5.36),
            (46.964123375120096, 6.926077007081328, 5.15),
            (46.964271046225896, 6.926079086386585, 6.12),
            (46.96443823203346, 6.926104787800326, 5.84),
            (46.96460504833385, 6.926159670597063, 6.17),
            (46.9647687234661, 6.926232909685224, 5.84),
            (46.96489580949113, 6.926351544793201, 4.74),
            (46.965031763276365, 6.9264140015114934, 5.52),
            (46.96515329036492, 6.9265239349244725, 6.33),
            (46.96527827520733, 6.926652838180974, 6.56),
            (46.965378192659344, 6.9268260484127016, 5.0),
            (46.96543929627477, 6.9270264593683875, 5.55),
            (46.96549280004578, 6.927244854776996, 6.8),
            (46.96555559923179, 6.9274438970611465, 5.4),
            (46.96565817962119, 6.927526293366207, 5.38),
            (46.965794909995175, 6.927499976152024, 5.85),
            (46.96595039122383, 6.927491003459347, 6.91),
            (46.96606751652734, 6.927616466596916, 5.22),
            (46.96616656831017, 6.927736730406148, 3.06),
            (46.966285415679, 6.9278355220320895, 5.98),
            (46.96642691614845, 6.92793334647426, 6.33),
            (46.96658322701254, 6.927981660889762, 6.01),
            (46.966749793041316, 6.927937044459732, 8.44),
            (46.96689595307383, 6.927935460121888, 5.72),
            (46.967021274797595, 6.928057303795344, 6.4),
            (46.967068468856546, 6.9282803297973, 5.86),
            (46.967139066638, 6.928502155607627, 5.65),
            (46.9672431228086, 6.928663986461625, 5.93),
            (46.96737091177967, 6.928762312092707, 5.43),
            (46.967502789402, 6.9288492612408765, 5.95),
            (46.96765113584548, 6.928888699963451, 7.15),
            (46.9678059991653, 6.92892127420531, 4.96),
            (46.96795981824509, 6.928908232847926, 5.76),
            (46.96809766858662, 6.928843241043752, 5.07),
            (46.96822533574118, 6.92885268522389, 5.41),
            (46.96835324511683, 6.928877127671032, 5.06),
            (46.96848936223972, 6.928894309559553, 5.54),
            (46.96862606959268, 6.928948015176373, 5.77),
            (46.968763192047, 6.929050693213733, 6.13),
            (46.968853393445656, 6.929189276944744, 4.69),
            (46.96896656332897, 6.929297759266105, 5.67),
            (46.9690665492425, 6.92941241292876, 5.27),
            (46.96915533769781, 6.929551900304361, 4.5),
            (46.969261393397474, 6.92966368572312, 6.02),
            (46.969373372122874, 6.929753950838668, 5.61),
            (46.96950714647564, 6.929788153923604, 5.22),
            (46.969652743170194, 6.929742492029775, 5.14),
            (46.96979640492144, 6.929753096281159, 4.89),
            (46.96986658148823, 6.92989404774067, 5.45),
            (46.96996606699119, 6.930044016676597, 5.85),
            (46.97009219256484, 6.930162643398199, 5.78),
            (46.970208856867146, 6.930287101172454, 4.95),
            (46.97030874893384, 6.9304312719194945, 5.01),
            (46.970416893159005, 6.930531263421116, 6.45),
            (46.97050537038262, 6.9306907022389765, 6.01),
            (46.970582207262446, 6.930865868508985, 5.01),
            (46.970694298472246, 6.930981791822016, 3.46),
            (46.97080524987319, 6.931117052702699, 5.91),
            (46.970938865611025, 6.931211021377895, 5.64),
            (46.97108762904458, 6.931298995068821, 6.23),
            (46.971195679168794, 6.931432247001272, 5.49),
            (46.9713061509957, 6.931576136279446, 4.88),
            (46.97142083405055, 6.931638772844521, 3.97),
            (46.971554852008765, 6.931632120953305, 5.9),
            (46.9716819518373, 6.931728867039817, 4.99),
            (46.97175625254519, 6.931917903523312, 5.62),
            (46.97182176420969, 6.932138232568077, 5.85),
            (46.971896110520795, 6.932378069935397, 5.42),
            (46.97197699086767, 6.932590848597108, 5.38),
            (46.972056265554514, 6.932772263495878, 5.23),
            (46.972130497604276, 6.932932792154367, 5.05),
            (46.97221895538756, 6.933028432432168, 4.59),
            (46.97235041181212, 6.933047808074897, 5.72),
            (46.972500484464426, 6.933055239568886, 5.7),
            (46.97264837881142, 6.933061187673368, 5.75),
            (46.972732290872386, 6.933201752877067, 5.8),
            (46.972784613991855, 6.933391240624976, 7.26),
            (46.97283076732806, 6.933589293040142, 5.42),
            (46.972890129322344, 6.933801139963286, 5.27),
            (46.972995664581205, 6.9339784657138495, 5.96),
            (46.97309634758037, 6.934170578257693, 6.07),
            (46.97318512637933, 6.934393992318545, 5.72),
            (46.9732764665274, 6.93460422272071, 7.36),
            (46.97338449326957, 6.934794184655976, 6.04),
            (46.97348838280354, 6.934959462828264, 3.83),
            (46.97361302731068, 6.9350664701411535, 5.64),
            (46.973742543157464, 6.935123654307228, 5.19),
            (46.973862062021055, 6.935199637435973, 5.48),
            (46.97400175911321, 6.935257618693692, 6.18),
            (46.97413526007133, 6.935250461819194, 5.06),
            (46.97426353268586, 6.93533566831157, 6.45),
            (46.97438098455928, 6.935502323412311, 6.67),
            (46.97444426158687, 6.935723202961238, 5.04),
            (46.974533687012304, 6.9359036697259375, 5.8),
            (46.974650652242836, 6.936042161053651, 6.99),
            (46.97472759063305, 6.936228812503265, 5.02),
            (46.974797889567995, 6.936415455942334, 5.46),
            (46.974861867633976, 6.93662859862724, 6.16),
            (46.97495282268536, 6.936746626422186, 6.31),
            (46.975056588380276, 6.936804648581164, 3.37),
            (46.975143192145346, 6.9368624566509185, 5.55),
            (46.97519022595396, 6.937030866946154, 6.01),
            (46.97522401197899, 6.937265380085943, 5.54),
            (46.97527656989677, 6.937464619903908, 7.16),
            (46.97532488799944, 6.937688380843648, 5.87),
            (46.97539687638089, 6.937887115859616, 5.57),
            (46.97547386807587, 6.938069181398109, 6.44),
            (46.975549808390355, 6.938263087498724, 6.13),
            (46.97561392515347, 6.93845714277927, 6.33),
            (46.97572498477144, 6.938607421058772, 5.17),
            (46.975847792924874, 6.938701950877965, 5.62),
            (46.97596359248439, 6.938833149498457, 4.65),
            (46.976095595784166, 6.938924063603812, 6.04),
            (46.97622453910318, 6.939003098116302, 5.36),
            (46.97631304708176, 6.939162497433218, 5.4),
            (46.97638194545191, 6.939358026648538, 6.12),
            (46.97644106852388, 6.9395737610210775, 5.74),
            (46.976464189793234, 6.939810015654883, 4.27),
            (46.97649116982342, 6.940023238331233, 3.72),
            (46.97655270418891, 6.940198594206099, 6.43),
            (46.97664033281799, 6.940374465795299, 5.98),
            (46.97674408486042, 6.9405185953916355, 5.03),
            (46.97682545904853, 6.9406987398485, 6.32),
            (46.97690489884762, 6.940872866341587, 5.4),
            (46.97699174182628, 6.9410271663064025, 6.12),
            (46.97702391751809, 6.941202575763462, 3.22),
            (46.977064655535976, 6.941327016622472, 5.22),
            (46.97715705269912, 6.941443989868976, 5.34),
            (46.97730105549324, 6.941463586333579, 5.47),
            (46.977451132984974, 6.941495516637064, 4.94),
            (46.97757412905752, 6.941622073252151, 6.1),
            (46.97766715832958, 6.941779718269434, 4.72),
            (46.97774235580933, 6.941922806024357, 3.99),
            (46.977827629578314, 6.942073078016341, 6.74),
            (46.97791915806957, 6.942251924762958, 6.16),
            (46.97799671496843, 6.942409669906565, 3.76),
            (46.978073637978724, 6.942538384384747, 5.96),
            (46.97815712057274, 6.9426995585350575, 5.51),
            (46.97826826380399, 6.942863102808428, 5.99),
            (46.978331566898184, 6.943059095344037, 4.93),
            (46.97843580981452, 6.943186949473952, 6.02),
            (46.97853328541547, 6.943335097673595, 5.53),
            (46.978603311472696, 6.943490874809573, 4.31),
            (46.97870023455002, 6.943599127730491, 5.37),
            (46.97883362815632, 6.943641067382169, 5.65),
            (46.978983470433604, 6.9436509342475405, 5.54),
            (46.979108032438404, 6.943762017308396, 6.56),
            (46.97919183041767, 6.94393659353307, 5.47),
            (46.97926713467522, 6.944132195830182, 4.13),
            (46.97937273491737, 6.944260778452639, 5.06),
            (46.97950917279914, 6.944362725112333, 6.75),
            (46.979631177464725, 6.944527599670522, 7.04),
            (46.979740363800936, 6.944705653995227, 5.43),
            (46.979853462571974, 6.944836377983826, 5.04),
            (46.9799287779491, 6.945007142886414, 5.81),
            (46.979965327950254, 6.945221298496673, 6.22),
            (46.979982277878364, 6.945458130123181, 6.52),
            (46.980014517085614, 6.945707972383874, 5.71),
            (46.98002700153597, 6.945950148379325, 6.85),
            (46.98004293744355, 6.946194998612848, 5.57),
            (46.98007896031567, 6.946421528462329, 5.86),
            (46.98013801137841, 6.946618712083313, 5.15),
            (46.98019991740699, 6.94680118175251, 5.64),
            (46.98027900337355, 6.946971690224682, 4.87),
            (46.98038455571495, 6.947070345900444, 5.84),
            (46.98053563743417, 6.9470947186670955, 6.08),
            (46.98069893575845, 6.947064188619088, 5.74),
            (46.98085521214316, 6.947051144689882, 6.11),
            (46.980942599127495, 6.947202729086472, 6.08),
            (46.98101431126979, 6.9474220762858945, 6.79),
            (46.981054423155385, 6.947645426845452, 3.23),
            (46.981106779507535, 6.947811271880323, 5.66),
            (46.98116805172458, 6.947976617613127, 5.55),
            (46.981261929952744, 6.948112335243819, 5.48),
            (46.98135799173079, 6.9482790491604245, 6.33),
            (46.98146161380774, 6.948449650235029, 5.94),
            (46.98154139807556, 6.948609351246657, 5.76),
            (46.98168831291952, 6.948699438084484, 6.8),
            (46.9818274494869, 6.948832870547313, 6.68),
            (46.9819363808715, 6.949014441187577, 5.93),
            (46.982031926826245, 6.949179806972278, 6.11),
            (46.98214831578371, 6.949329825329548, 6.44),
            (46.98230781972276, 6.949402930961495, 6.02),
            (46.98245228592407, 6.9494440952698495, 4.29),
            (46.98250308999973, 6.949595097501678, 5.99),
            (46.98246656824573, 6.949804378931519, 4.49),
            (46.982492035836046, 6.949945994247764, 4.74),
            (46.982543558372484, 6.950123212116226, 6.02),
            (46.98258114228306, 6.950316187853041, 5.89),
            (46.982642509536724, 6.9505326641527345, 5.2),
            (46.98271504834769, 6.950736299394393, 5.65),
            (46.9828095469009, 6.950916918255274, 5.66),
            (46.982957750776464, 6.951005118659347, 5.62),
            (46.9831160213245, 6.951072740902691, 5.73),
            (46.983236304158915, 6.951190822878684, 5.73),
            (46.983299765463556, 6.951383666253807, 5.96),
            (46.98338497903759, 6.9515751644522386, 6.92),
            (46.98351199064954, 6.951680818169187, 5.34),
            (46.983665603119405, 6.951778369079928, 7.48),
            (46.98380795178424, 6.951906255636503, 5.28),
            (46.983931078571715, 6.952012607679091, 5.79),
            (46.984062111769035, 6.952137740196151, 6.52),
            (46.9841767746237, 6.952294475224504, 5.48),
            (46.98426902456169, 6.952467042003153, 6.15),
            (46.984326383609314, 6.952680476599836, 7.35),
            (46.9843588933346, 6.952907965894609, 4.91),
            (46.984414665235605, 6.953127513097016, 6.39),
            (46.98449453002539, 6.9533371667361905, 6.58),
            (46.98462671216717, 6.953473327225284, 5.66),
            (46.984788098717765, 6.953482930328697, 5.77),
            (46.98496143452309, 6.95349965564081, 6.61),
            (46.98513856779608, 6.953459601306521, 6.15),
            (46.98528909901781, 6.953411760066982, 5.09),
            (46.98542546270986, 6.95338143477007, 4.78),
            (46.985508722269934, 6.953482466950867, 5.9),
            (46.985625417893985, 6.953584647111457, 5.97),
            (46.985758976578765, 6.953684831827727, 5.65),
            (46.98590391804973, 6.953782399809639, 5.93),
            (46.98602541303798, 6.953928281560758, 5.68),
            (46.98615925175088, 6.954060721978636, 5.81),
            (46.98628066298238, 6.9540973692594035, 5.15),
            (46.98633891256199, 6.954029243736515, 0.11),
            (46.98634173124712, 6.954007827782317, 0.69),
            (46.98631961360608, 6.954010156428784, 0.29),
            (46.986308140005555, 6.954006182757705, 0.41),
            (46.98630909442798, 6.954004606494054, 0.48),
            (46.986312694219926, 6.954009583967234, 0.23),
            (46.986325260813025, 6.954015073316165, 0.32),
            (46.9863334994596, 6.954026268539198, 0.27),
            (46.986340256455314, 6.9540345649805255, 0.88),
            (46.98635023084545, 6.954048343751879, 0.27),
            (46.98635999571643, 6.954062274463652, 0.09),
            (46.986370793509536, 6.954078115797385, 0.3),
            (46.98637910543667, 6.954092907074374, 0.13),
            (46.986386875809195, 6.954103172262983, 0.59),
            (46.986391773706266, 6.954115594363986, 0.17),
            (46.98639444370008, 6.954125250842284, 0.18),
            (46.986399062116334, 6.954133311790507, 0.54),
            (46.98640429241598, 6.954142419013225, 0.64),
            (46.98641046794608, 6.954153771783848, 0.25),
            (46.98641443376862, 6.954165438315882, 0.25),
            (46.98641558069473, 6.954179954167887, 0.73),
            (46.98641770913294, 6.954192835495924, 0.4),
            (46.98641917969146, 6.9542063013339055, 0.38),
            (46.986425608983915, 6.954212387264519, 0.44),
            (46.986432261803074, 6.954219572794443, 0.36),
            (46.98644102848443, 6.954228743994634, 0.39),
            (46.986451545894234, 6.954235793991436, 0.56),
            (46.98645828040831, 6.9542396862395455, 0.54),
            (46.98646556861256, 6.9542403143521625, 0.77),
            (46.986472283413335, 6.954246975077663, 0.39),
            (46.98648239905655, 6.954257773141423, 0.24),
            (46.98648781615661, 6.954275075762024, 0.49),
            (46.98649068923876, 6.954292185199821, 0.22),
            (46.98649390765869, 6.954304494221696, 0.84),
            (46.986498840956294, 6.954317342106589, 0.36),
            (46.9865036923726, 6.954334774939559, 0.48),
            (46.986509255452575, 6.9543594438761716, 0.47),
            (46.9865143221274, 6.954382635890833, 0.24),
            (46.98651975957047, 6.9544014712146485, 0.55),
            (46.986528687102634, 6.954422078815203, 0.61),
            (46.986537658050466, 6.954439876270964, 0.58),
            (46.98654808944318, 6.9544532099955125, 0.93),
            (46.98656180144584, 6.954466927019103, 0.49),
            (46.98657263927438, 6.954470738056199, 0.46),
            (46.986583476675406, 6.954481582542331, 0.74),
            (46.98659229261662, 6.95449863945881, 0.74),
            (46.98660102679402, 6.954511777279588, 0.8),
            (46.98661995782026, 6.954533058601888, 1.33),
            (46.98664208016062, 6.954554230674978, 0.81),
            (46.986649972578725, 6.954605669219112, 1.49),
            (46.98664753239277, 6.954673834075139, 1.99),
            (46.986628577693615, 6.954761702251297, 2.85),
            (46.9865978716256, 6.954902270452107, 4.94),
            (46.98655334569285, 6.955095722007068, 5.2),
            (46.9865487674953, 6.9552946496797645, 4.4),
            (46.9865232567021, 6.955481862865484, 4.75),
            (46.98644667231096, 6.9556294246542505, 2.46),
            (46.98636318517415, 6.955791395273167, 6.27),
            (46.98634435775073, 6.956006582496459, 5.6),
            (46.98635718620226, 6.956255114843887, 6.93),
            (46.986369470549164, 6.956535579993196, 6.65),
            (46.986371212695815, 6.956779270262283, 4.96),
            (46.98640929852957, 6.956995270781322, 5.87),
            (46.98646342718511, 6.95721117936638, 5.96),
            (46.986532936292235, 6.95741431490442, 5.7),
            (46.98660078848591, 6.957620478560309, 5.39),
            (46.98669010812268, 6.957798914140631, 5.65),
            (46.98679322369955, 6.9579516739723895, 4.64),
            (46.986929781438, 6.958027350121963, 5.71),
            (46.98709332644218, 6.958079739329229, 6.57),
            (46.98727128069232, 6.958097914016607, 6.12),
            (46.98745351584509, 6.958128287237676, 6.87),
            (46.98763349540714, 6.958134097355192, 6.05),
            (46.98778704209708, 6.958166383741786, 4.83),
            (46.98791957779603, 6.958195224513658, 4.93),
            (46.98805156413943, 6.9582555229944125, 5.75),
            (46.988187538140075, 6.958335822449967, 5.45),
            (46.988307970325145, 6.958453295797037, 5.06),
            (46.988428310215276, 6.958587508506081, 5.8),
            (46.98851928498633, 6.958762377892861, 4.55),
            (46.98861730761035, 6.958878832753205, 5.26),
            (46.98874913072393, 6.958944353527381, 5.93),
            (46.98888265055189, 6.959006254007868, 5.45),
            (46.989032990832754, 6.959068328255046, 5.08),
            (46.98918898847206, 6.959125552918594, 6.05),
            (46.989345143262035, 6.959176551856365, 5.74),
            (46.989479111943034, 6.959255660151044, 5.44),
            (46.98957928094158, 6.959419056862325, 6.12),
            (46.98965940171151, 6.959636560596549, 6.19),
            (46.989726175028906, 6.959856657999024, 5.28),
            (46.98979598100552, 6.9600473386305275, 4.53),
            (46.98986935221455, 6.960218837361803, 5.26),
            (46.98995317586382, 6.960390063599269, 5.59),
            (46.99000552396179, 6.96058975676788, 5.06),
            (46.99006795694554, 6.9607648849641235, 5.44),
            (46.99015332332548, 6.960913023385122, 5.6),
            (46.99022476202203, 6.96110027983364, 6.21),
            (46.99030009879923, 6.9612961755259075, 5.13),
            (46.9903510942735, 6.961508960581906, 5.68),
            (46.990413481536564, 6.961724326772527, 6.52),
            (46.990500457914706, 6.961918043582604, 5.93),
            (46.990531513117226, 6.962118237199595, 4.75),
            (46.99055863002932, 6.962300246897016, 5.6),
            (46.99061439311017, 6.962460940445425, 6.21),
            (46.99073697542961, 6.962584867713704, 5.92),
            (46.99085952284931, 6.962735805610297, 5.82),
            (46.990984438953056, 6.9628727582943215, 5.63),
            (46.99112198589766, 6.962979441242945, 5.59),
            (46.991258793947836, 6.963088792429023, 5.28),
            (46.991407147323535, 6.963162238090917, 6.32),
            (46.99156614912575, 6.963227182039924, 5.61),
            (46.991623129415075, 6.963404570362986, 5.98),
            (46.99163096712644, 6.963650347832697, 6.83),
            (46.9916034545194, 6.963876695654784, 3.7),
            (46.99163836276717, 6.964076077606466, 6.22),
            (46.99170457120454, 6.964293827646592, 5.97),
            (46.99181544127116, 6.964488355562259, 6.02),
            (46.991915625635016, 6.964679702811799, 5.78),
            (46.99202621343022, 6.964833764073724, 6.01),
            (46.99218310954588, 6.964919019593125, 7.03),
            (46.992340041569264, 6.964970235649629, 5.87),
            (46.992503743003006, 6.965009791993408, 6.5),
            (46.99266303987107, 6.965031348099838, 6.01),
            (46.992782173895506, 6.965148206836746, 6.12),
            (46.99289561640279, 6.965301762618354, 6.75),
            (46.993018175193086, 6.965474544664684, 6.08),
            (46.99312364272748, 6.965651709330371, 5.82),
            (46.993204764569164, 6.965847448321259, 6.47),
            (46.99331926898246, 6.96600319246492, 6.52),
            (46.993442409228344, 6.966147648651598, 5.75),
            (46.99357546988405, 6.96625096265741, 6.36),
            (46.99372715897094, 6.966328080389192, 6.47),
            (46.99386835469336, 6.966449674699221, 6.16),
            (46.99399729513707, 6.966609566404842, 6.12),
            (46.9940750559002, 6.966812722813093, 6.05),
            (46.9941121483053, 6.967035443861225, 6.45),
            (46.99415785271154, 6.967261749371278, 6.41),
            (46.99419625701918, 6.967481845682831, 5.89),
            (46.994251066829875, 6.967658107842234, 4.6),
            (46.994369358405194, 6.967720051286212, 6.11),
            (46.99448517851391, 6.967814130497737, 5.77),
            (46.99462452502288, 6.967889720054303, 5.89),
            (46.99476230117573, 6.968007777762686, 6.57),
            (46.99490468453553, 6.96814769721113, 5.85),
            (46.99499060117135, 6.968316670627261, 5.27),
            (46.995048549898506, 6.968511358717185, 6.47),
            (46.99508758336118, 6.968724007325112, 5.32),
            (46.99512211723134, 6.968947581796965, 6.5),
            (46.99512346968184, 6.969173520964601, 5.06),
            (46.9951525144294, 6.969380746564743, 4.89),
            (46.99522190775755, 6.96954516282893, 6.69),
            (46.99533914935198, 6.969644252243036, 4.71),
            (46.99547179492008, 6.96973187986601, 5.86),
            (46.99555635904234, 6.969892838420465, 4.63),
            (46.99565905252971, 6.969978556531278, 6.31),
            (46.99575352579155, 6.970068156385059, 3.96),
            (46.995835115648774, 6.970157962030761, 5.71),
            (46.995881158718674, 6.970320001793461, 6.8),
            (46.9960009762459, 6.9704162400683884, 4.52),
            (46.99614370352536, 6.9704666544915685, 6.45),
            (46.996309805865145, 6.970470036395265, 5.75),
            (46.99645518024253, 6.9705039854145285, 5.77),
            (46.996587167068974, 6.970555663890556, 5.66),
            (46.996650631579136, 6.970719383244491, 5.82),
            (46.99669006079771, 6.970950675202722, 5.84),
            (46.99671555133106, 6.971199611934124, 5.69),
            (46.99673255101691, 6.971455401636993, 5.48),
            (46.9967423436364, 6.971692391152564, 5.64),
            (46.99677477786573, 6.971919916152475, 7.37),
            (46.99686604400175, 6.97209554444577, 4.67),
            (46.99700083245432, 6.97218851311632, 5.57),
            (46.997130006178864, 6.972278799400413, 4.81),
            (46.99725260294628, 6.972379376456244, 5.88),
            (46.99737652035353, 6.972498912762993, 5.34),
            (46.997443323685616, 6.972667666524556, 5.08),
            (46.99750150021, 6.972866889158722, 6.84),
            (46.99756392906437, 6.973102092995393, 7.36),
            (46.99761435073813, 6.973327826959628, 2.99),
            (46.997690841366826, 6.973489406797625, 5.1),
            (46.9978125625126, 6.973608401244474, 6.26),
            (46.99795129924878, 6.973704910694493, 4.18),
            (46.998101622278405, 6.973714192419992, 5.29),
            (46.998237833372436, 6.973727929304641, 6.14),
            (46.99827475957831, 6.973873401577904, 4.22),
            (46.998296127482014, 6.97408138412945, 5.73),
            (46.99825417301153, 6.974310557426548, 4.71),
            (46.998264376269226, 6.974473437061818, 4.52),
            (46.99835085210796, 6.974604379782382, 5.96),
            (46.99845778122508, 6.974754734113297, 5.99),
            (46.99858331152962, 6.974921720382811, 6.5),
            (46.998732854672646, 6.975072896659235, 6.28),
            (46.99887661531132, 6.975209400176219, 4.55),
            (46.9990348732383, 6.975263569804799, 6.64),
            (46.99913240500441, 6.9754451907444315, 7.15),
            (46.99919034068897, 6.975641581573216, 5.33),
            (46.99930704309022, 6.975684406728073, 6.07),
            (46.99941178199163, 6.975747625040444, 6.04),
            (46.99949086685987, 6.975914160878131, 5.62),
            (46.99957451352276, 6.976099663227097, 5.41),
            (46.99965353020582, 6.976288428329061, 6.52),
            (46.99974327463528, 6.976475683189992, 5.64),
            (46.999839891844246, 6.976658728754886, 5.87),
            (46.99990709892748, 6.976843207324059, 5.63),
            (46.99995677768697, 6.97703532819985, 4.96),
            (47.000021196068566, 6.977182333438275, 5.21),
            (47.00013961125255, 6.977218601554518, 5.39),
            (47.00022536314326, 6.9773575253856555, 5.79),
            (47.00026122050483, 6.977548306669449, 5.55),
            (47.000266483740354, 6.977765976319987, 5.7),
            (47.000292346066686, 6.977963516844621, 5.73),
            (47.000357697963544, 6.978118034522731, 4.03),
            (47.00046584739705, 6.978170779724005, 4.32),
            (47.00056509825603, 6.978241794560333, 4.6),
            (47.000653416026694, 6.978330467072372, 4.2),
            (47.0007672098256, 6.978445975998031, 5.76),
            (47.000855367436095, 6.978590409998057, 4.13),
            (47.000957702367316, 6.97869924337831, 5.11),
            (47.001080477000215, 6.978803154933064, 5.94),
            (47.0011970422649, 6.978927020267129, 5.29),
            (47.00134381843888, 6.979003691320077, 6.92),
            (47.001494539286625, 6.9790569924898165, 5.58),
            (47.00164474127856, 6.979090567344938, 5.21),
            (47.001778392560965, 6.979152332723508, 3.85),
            (47.00186029924192, 6.9792671766949015, 4.84),
            (47.001955908637335, 6.97938437586121, 5.91),
            (47.00204510608906, 6.979541666710807, 5.72),
            (47.00211058252687, 6.979731523385915, 5.49),
            (47.002088416397015, 6.979948597112567, 5.06),
            (47.00210086395262, 6.980134283831661, 5.22),
            (47.00218354520896, 6.980268602494387, 5.3),
            (47.00229453025181, 6.980362691499856, 5.39),
            (47.0024334003422, 6.980411750880185, 4.23),
            (47.00255663925701, 6.980518654028215, 6.35),
            (47.00267723806198, 6.9806604898524744, 5.8),
            (47.00278535625543, 6.980778202539738, 4.53),
            (47.002883593411944, 6.9809401875337835, 5.65),
            (47.00298224359747, 6.981069265908768, 6.83),
            (47.00306798134886, 6.981219730428639, 5.3),
            (47.0031212744422, 6.981397027061009, 5.2),
            (47.00318070950326, 6.981529735007221, 4.28),
            (47.003278664799915, 6.981595898555708, 5.08),
            (47.00338503742431, 6.9817100275285435, 6.11),
            (47.003468115187616, 6.981882044897379, 5.77),
            (47.00354008566391, 6.9820837149860635, 5.28),
            (47.003588134948494, 6.982293887772859, 4.74),
            (47.00363282759103, 6.982508855299656, 6.04),
            (47.0037006090612, 6.982699643345109, 6.15),
            (47.00378083324276, 6.9828801366416595, 5.71),
            (47.00383848273453, 6.9830658106425405, 4.9),
            (47.003928025384035, 6.983200548221793, 6.1),
            (47.00400895192526, 6.983306996935485, 3.95),
            (47.00410395756084, 6.98340396310112, 4.87),
            (47.0042268278287, 6.983484011639657, 6.05),
            (47.00435615454783, 6.98354866046383, 3.89),
            (47.00449289335514, 6.983612978871962, 6.41),
            (47.0046419167245, 6.983619720411526, 5.61),
            (47.00477956046324, 6.983636857327356, 3.84),
            (47.00488024692683, 6.983735026284093, 5.74),
            (47.00498613921722, 6.983847231496454, 5.25),
            (47.005106705272354, 6.983931690342837, 6.19),
            (47.00522748149153, 6.984027574605525, 5.4),
            (47.00536062775975, 6.984094440280899, 5.9),
            (47.00549319250825, 6.984162271668115, 5.35),
            (47.00563729963694, 6.9841151521069715, 5.29),
            (47.00578212262926, 6.984061943027087, 5.74),
            (47.00592859299842, 6.9840315932194255, 5.66),
            (47.0060804278267, 6.984030398501452, 5.8),
            (47.00623282948975, 6.984070950687126, 5.04),
            (47.00635681918226, 6.98414954815798, 4.87),
            (47.00646509973208, 6.984245008474298, 5.02),
            (47.00653637695715, 6.9842731442370525, 1.0),
            (47.006659695693315, 6.984358198885993, 4.36),
            (47.006788030323, 6.984465290553924, 6.9),
            (47.006877033503564, 6.9846274490443, 5.99),
            (47.0070060133444, 6.9847457582065795, 6.73),
            (47.0070675621774, 6.984959365535218, 5.97),
            (47.00712512791676, 6.985190030830589, 5.2),
            (47.00722126282039, 6.9853407053143854, 6.85),
            (47.00730949512565, 6.985526678391127, 5.64),
            (47.007389838202904, 6.9856969796540405, 5.22),
            (47.007493437422056, 6.985855584224736, 6.22),
            (47.00758870473392, 6.985986602185145, 4.95),
            (47.00768472367407, 6.98611340675438, 4.63),
            (47.00776314476441, 6.986234145103746, 5.67),
            (47.007861597924105, 6.986332699216362, 6.14),
            (47.007941322295, 6.986490369513219, 6.48),
            (47.00801691567798, 6.98664808471172, 5.49),
            (47.0081117866512, 6.986775008856253, 5.98),
            (47.00820328232471, 6.986896443897518, 5.39),
            (47.00830015342685, 6.987032674536908, 5.93),
            (47.00838150836819, 6.987223918406719, 5.72),
            (47.00841586018504, 6.987425998144433, 5.65),
            (47.00838921297471, 6.987633701821367, 4.76),
            (47.00841206064542, 6.987857037376246, 7.08),
            (47.00847491447849, 6.988078799405076, 5.71),
            (47.00860387141613, 6.988090656499181, 5.62),
            (47.00874794736513, 6.988039408231553, 5.14),
            (47.00891592476928, 6.987952776434552, 5.53),
            (47.00904151996554, 6.987919172820616, 2.66),
            (47.009108425338574, 6.9879250061166855, 0.67),
            (47.009077684099, 6.987920339114089, 0.32),
            (47.00903464798566, 6.987906139249375, 0.29),
            (47.00900198750065, 6.987902526326335, 0.67),
            (47.00898136498163, 6.9879150412354605, 1.07),
            (47.00896165583819, 6.98792566158578, 0.76),
            (47.00896698739898, 6.9879316165098935, 0.81),
            (47.00897214548442, 6.987935942828106, 0.05),
            (47.008989448784966, 6.987949872269891, 0.22),
            (47.00899411747872, 6.987952749817883, 0.49),
        ]
        return pts.enumerated().map { i, p in
            LocationData(timestamp: Date.now.addingTimeInterval(Double(i) * 3.0), latitude: p.0, longitude: p.1, altitude: 0, speed: p.2)
        }
    }()

    static func parawingDownwindRun() -> RunStatistic {
        let locations = parawingDownwindRunLocations
        var statistic = RunStatistic(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
            runName: "DW Parawing",
            crewStatistics: [],
            runTime: 87.0,
            runDistance: 26246,
            topSpeed: 32.8,
            averageSpeed: 18.1,
            kCalories: 980,
            locationData: locations,
            tags: ["#850S", "#65ML"],
            workoutType: .dWParawing,
            startDate: locations.first?.timestamp ?? Date.now,
            endDate: locations.last?.timestamp ?? Date.now,
            topSpeed1s: 34.2,
            topSpeed10s: 28.6,
            popUps: 3,
            percentageOnFoil: 88.7,
            turnsCount: 808
        )
        statistic.locationString = "Saint-Aubin-Sauges → St-Blaise"
        statistic.startLocation = locations.first
        statistic.longestDistanceOnFoil = 20300
        statistic.averageHeartRate = 128
        return statistic
    }
}

private extension [Double] {
    func smoothed(window: Int) -> [Double] {
        guard count > 1 else { return self }
        let half = window / 2
        var cumulative = [Double](repeating: 0, count: count + 1)
        for i in 0..<count {
            cumulative[i + 1] = cumulative[i] + self[i]
        }
        return (0..<count).map { i in
            let lo = Swift.max(0, i - half)
            let hi = Swift.min(count - 1, i + half)
            return (cumulative[hi + 1] - cumulative[lo]) / Double(hi - lo + 1)
        }
    }
}

#endif
