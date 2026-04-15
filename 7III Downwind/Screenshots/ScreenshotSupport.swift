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
        bestExportStatistic() ?? featuredStatistic(id: liveBundle?.featured.exportRunID) ?? statistic(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
            name: "January Foil",
            startDate: date(year: 2025, month: 1, day: 28, hour: 9, minute: 50),
            locationString: "Concise → St-Blaise",
            runTime: 107,
            distance: 31070,
            topSpeed: 29,
            averageSpeed: 17,
            tags: ["#850S", "#65ML"],
            workoutType: .downwindSUPFoil,
            speedMultiplier: 1.02
        )
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
                name: "DW SUP Foil",
                day: 28,
                hour: 15,
                minute: 10,
                location: "Neuenburg -> St-Blaise",
                runTime: 22.83,
                distance: 5320,
                topSpeed: 24,
                averageSpeed: 14,
                tags: ["#3frigate", "#4.7frigate", "#4brm", "#105dw", "#1130S", "#850S"],
                workoutType: .downwindSUPFoil,
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
                tags: ["#850S"],
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
                tags: ["#980S", "#foil"],
                workoutType: .foilSurf,
                speedMultiplier: 0.86
            ),
            fallbackStatistic(
                id: "ABABABAB-2222-2222-2222-222222222222",
                name: "DW SUP Foil",
                day: 24,
                hour: 11,
                minute: 18,
                location: "Neuenburg -> St-Blaise",
                runTime: 94,
                distance: 27420,
                topSpeed: 31.3,
                averageSpeed: 17.5,
                tags: ["#4brm", "#850S"],
                workoutType: .downwindSUPFoil,
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
                location: "Neuenburg -> St-Blaise",
                runTime: 102,
                distance: 29840,
                topSpeed: 32.2,
                averageSpeed: 17.9,
                tags: ["#1130S", "#850S"],
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
                tags: ["#4.5ensis", "#700R"],
                workoutType: .parawing,
                speedMultiplier: 0.73
            ),
            fallbackStatistic(
                id: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE",
                name: "DW Parawing",
                day: 2,
                hour: 12,
                minute: 7,
                location: "Saint-Aubin-Sauges",
                runTime: 164,
                distance: 9470,
                topSpeed: 9.1,
                averageSpeed: 3.5,
                tags: ["#850S", "#65ML"],
                workoutType: .parawing,
                speedMultiplier: 0.38
            ),
            statistic(
                id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") ?? UUID(),
                name: "DW SUP Foil",
                startDate: date(year: 2024, month: 12, day: 7, hour: 12, minute: 50),
                locationString: "Saint-Aubin-Sauges -> St-Blaise",
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
                locationString: "Saint-Aubin-Sauges -> St-Blaise",
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
        let heartRates = statistic.locationData.enumerated().compactMap { index, location -> HeartRate? in
            guard index.isMultiple(of: 18) else { return nil }
            return HeartRate(date: location.timestamp, heartRate: 124 + Double((index / 18) % 22))
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

private struct ScreenshotStatisticContainer<Content: View>: View {
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

struct FakeExportMenuOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            menuRow(title: "Video", icon: "film")
            Divider()
            menuRow(title: "Photo", icon: "photo")
            Divider()
            menuRow(title: "GPX", icon: "point.bottomleft.forward.to.point.topright.scurvepath")
        }
        .frame(width: 270)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private func menuRow(title: String, icon: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: icon)
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

struct ScreenshotExportRunView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: ScreenshotSampleData.exportStatistic().id
            ) { statistic in
                StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic)
                    .overlay(alignment: .topTrailing) {
                        FakeExportMenuOverlay()
                            .padding(.top, 110)
                            .padding(.trailing, 28)
                    }
            }
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
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: ScreenshotSampleData.editStatistic().id
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
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        let statistic = ScreenshotSampleData.mapStatistic()

        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: statistic.id
            ) { statistic in
                if (statistic.wrappedValue.workoutType ?? .surf).isDWSport {
                    StatisticsMap(downwindManager: downwindManager, statisticsData: statistic)
                } else {
                    SpeedGradientStatisticsMap(statisticsData: statistic)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(statistic.locationString ?? "Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ScreenshotStatsDetailView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: ScreenshotSampleData.detailStatistic().id
            ) { statistic in
                StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic)
            }
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

private extension ScreenshotSampleData {
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

struct ScreenshotHyeresAngleToolView: View {
    @State private var showAngleMap = true

    var body: some View {
        let statistic = ScreenshotSampleData.hyeresStatistic()

        Color.clear
            .sheet(isPresented: $showAngleMap) {
                NavigationStack {
                    WindSportStatisticsMap(
                        downwindManager: DownwindManager(),
                        statisticsData: .constant(statistic),
                        angleTool: true
                    )
                    .navigationTitle(statistic.locationString ?? "Hyères")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showAngleMap = false }, label: {
                                XMarkLabel()
                            })
                        }
                    }
                }
            }
    }
}
#endif
