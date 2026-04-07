#if os(iOS)
import AppScreenshotKit
import CoreLocation
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
                    .stroke(screenshotNeonRouteColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }

            if showsMarkers {
                ForEach([points.first, points.last].compactMap { $0 }) { marker in
                    Circle()
                        .fill(marker.color)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                        }
                        .frame(width: 22, height: 22)
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

            var previousMidpoint = midpoint(routePoints[0], routePoints[1])
            path.addLine(to: previousMidpoint)

            for index in 1..<(routePoints.count - 1) {
                let current = routePoints[index]
                let next = routePoints[index + 1]
                let mid = midpoint(current, next)
                path.addQuadCurve(to: mid, control: current)
                previousMidpoint = mid
            }

            path.addQuadCurve(to: routePoints.last!, control: routePoints[routePoints.count - 2])
        }
    }

    private func makePoints() -> [WigglePoint] {
        var generator = SeededGenerator(seed: seed)
        let surpriseStyle = SurpriseStyle.allCases.randomElement(using: &generator) ?? .slingshot
        let markerRadius: CGFloat = 18
        let textKeepOut = textSafeRect == .zero ? .null : textSafeRect.insetBy(dx: -42, dy: -42)
        let markerKeepOutRects = [
            textKeepOut,
            deviceRect.insetBy(dx: -10, dy: -10)
        ].filter { !$0.isNull && !$0.isEmpty }
        let pathKeepOutRects = [textKeepOut].filter { !$0.isNull && !$0.isEmpty }
        let margin: CGFloat = 42
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

        let selectedPair = bestSeparatedMarkerPair(
            visibleDeviceCandidates: visibleDeviceCandidates,
            deviceCandidates: deviceCandidates,
            visibleSurpriseCandidates: visibleSurpriseCandidates,
            surpriseCandidates: surpriseCandidates,
            forbiddenRects: markerKeepOutRects,
            margin: margin,
            radius: markerRadius,
            generator: &generator
        )
        let devicePoint = selectedPair.device
        let remotePoint = selectedPair.remote
        let startNearDevice = Bool.random(using: &generator)
        let startPoint = startNearDevice ? devicePoint : remotePoint
        let endPoint = startNearDevice ? remotePoint : devicePoint

        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let length = max(sqrt((deltaX * deltaX) + (deltaY * deltaY)), 1)
        let direction = CGPoint(x: deltaX / length, y: deltaY / length)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let turns = min(
            surpriseStyle.maxTurns,
            max(
                surpriseStyle.minTurns,
                (length / surpriseStyle.turnDistanceDivisor)
                    + CGFloat.random(in: surpriseStyle.turnJitter, using: &generator)
            )
        )
        let pointCount = min(19, max(11, Int(length / 88) + Int.random(in: 0...2, using: &generator)))
        let amplitude = min(
            canvasSize.width * surpriseStyle.maxAmplitudeFactor,
            max(surpriseStyle.minAmplitude, length * surpriseStyle.distanceAmplitudeFactor)
        )
        let phase = CGFloat.random(in: 0...(2 * .pi), using: &generator)
        let includesLoop = length > canvasSize.width * 0.58 && Bool.random(using: &generator) && surpriseStyle.allowsLoop
        var routePoints = [startPoint]

        let loopCenter = CGFloat.random(in: 0.34...0.72, using: &generator)
        let loopWindow = CGFloat.random(in: 0.08...0.13, using: &generator)
        let alongOffsetAmplitude = min(
            surpriseStyle.maxAlongOffset,
            max(surpriseStyle.minAlongOffset, length * surpriseStyle.alongOffsetFactor)
        )

        for index in 1..<pointCount {
            let progress = CGFloat(index) / CGFloat(pointCount)
            let basePoint = CGPoint(
                x: startPoint.x + deltaX * progress,
                y: startPoint.y + deltaY * progress
            )

            var lateralOffset = sin(progress * turns * (.pi * 2) + phase) * amplitude
            lateralOffset += sin(progress * (turns + 1.35) * (.pi * 2) + phase * 0.6) * amplitude * 0.18
            var alongOffset = sin(progress * (.pi * 2) + phase * 0.35) * alongOffsetAmplitude

            if includesLoop {
                let loopProgress = (progress - loopCenter) / loopWindow
                if abs(loopProgress) < 1 {
                    let swirlAngle = loopProgress * (.pi * 2)
                    lateralOffset += cos(swirlAngle) * amplitude * 0.58
                    alongOffset += sin(swirlAngle) * amplitude * 0.28
                }
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

        return [
            WigglePoint(point: routePoints.first ?? startPoint, color: .green)
        ] + routePoints.dropFirst().dropLast().map {
            WigglePoint(point: $0, color: .clear)
        } + [
            WigglePoint(point: routePoints.last ?? endPoint, color: .red)
        ]
    }

    private func bestSeparatedMarkerPair(
        visibleDeviceCandidates: [CGPoint],
        deviceCandidates: [CGPoint],
        visibleSurpriseCandidates: [CGPoint],
        surpriseCandidates: [CGPoint],
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat,
        generator: inout SeededGenerator
    ) -> (device: CGPoint, remote: CGPoint) {
        let minimumDistance = min(
            max(canvasSize.width * 0.54, canvasSize.height * 0.36),
            diagonalDistance() * 0.72
        )

        let availableDeviceCandidates = visibleDeviceCandidates.isEmpty
            ? [visibleMarkerPoint(
                candidates: deviceCandidates.shuffled(using: &generator),
                forbiddenRects: forbiddenRects,
                margin: margin,
                radius: radius
            )]
            : visibleDeviceCandidates
        let availableSurpriseCandidates = visibleSurpriseCandidates.isEmpty
            ? [visibleMarkerPoint(
                candidates: surpriseCandidates.shuffled(using: &generator),
                forbiddenRects: forbiddenRects,
                margin: margin,
                radius: radius
            )]
            : visibleSurpriseCandidates

        let rankedPairs = availableDeviceCandidates.flatMap { devicePoint in
            availableSurpriseCandidates.map { remotePoint in
                MarkerPair(
                    device: devicePoint,
                    remote: remotePoint,
                    distance: distance(from: devicePoint, to: remotePoint)
                )
            }
        }
        .sorted { $0.distance > $1.distance }

        if let maxDistance = rankedPairs.first?.distance {
            let nearBestThreshold = max(maxDistance * 0.97, minimumDistance)
            let candidatePairs = rankedPairs
                .prefix(18)
                .filter { $0.distance >= nearBestThreshold }

            if let chosenPair = Array(candidatePairs).randomElement(using: &generator) ?? rankedPairs.first {
                return (device: chosenPair.device, remote: chosenPair.remote)
            }
        }

        let fallbackDevice = visibleMarkerPoint(
            candidates: deviceCandidates.shuffled(using: &generator),
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius
        )
        let orderedSurpriseFallbacks = surpriseCandidates
            .sorted { distance(from: fallbackDevice, to: $0) > distance(from: fallbackDevice, to: $1) }
        let fallbackRemote = visibleMarkerPoint(
            candidates: orderedSurpriseFallbacks,
            forbiddenRects: forbiddenRects,
            margin: margin,
            radius: radius
        )

        return (device: fallbackDevice, remote: fallbackRemote)
    }

    private func visibleMarkerPoint(
        candidates: [CGPoint],
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat
    ) -> CGPoint {
        for candidate in candidates {
            if isVisibleMarker(candidate, forbiddenRects: forbiddenRects, margin: margin, radius: radius) {
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
                if isVisibleMarker(fallback, forbiddenRects: forbiddenRects, margin: margin, radius: radius) {
                    return fallback
                }
            }
        }

        return CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private func isVisibleMarker(
        _ point: CGPoint,
        forbiddenRects: [CGRect],
        margin: CGFloat,
        radius: CGFloat
    ) -> Bool {
        guard point.x >= margin, point.x <= canvasSize.width - margin, point.y >= margin, point.y <= canvasSize.height - margin else {
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
        var adjusted = CGPoint(
            x: min(max(point.x, margin), canvasSize.width - margin),
            y: min(max(point.y, margin), canvasSize.height - margin)
        )

        for rect in keepOutRects where rect.contains(adjusted) {
            let pushLeft = abs(adjusted.x - rect.minX)
            let pushRight = abs(rect.maxX - adjusted.x)
            adjusted.x = pushLeft < pushRight ? rect.minX - 42 : rect.maxX + 42
            adjusted.x = min(max(adjusted.x, margin), canvasSize.width - margin)
            adjusted.y = rect.maxY + 24
        }

        return adjusted
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt((dx * dx) + (dy * dy))
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

    private struct MarkerPair {
        let device: CGPoint
        let remote: CGPoint
        let distance: CGFloat
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
            case .basementDive: return 380
            case .sideSwipe: return 360
            case .slingshot: return 340
            case .cornerChaos: return 310
            case .halo: return 330
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
            let phoneSize = CGSize(
                width: environment.screenshotSize.width * 0.95,
                height: environment.screenshotSize.height * 0.95
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

                DeviceView {
                    content
                        .preferredColorScheme(phoneColorScheme)
                }
                .statusBarShown()
                .frame(width: phoneSize.width, height: phoneSize.height)
                .offset(y: phoneOffsetY)

                NeonWiggleRoute(
                    seed: wiggleSeed,
                    canvasSize: proxy.size,
                    textSafeRect: textRect,
                    deviceRect: phoneRect,
                    showsLine: false,
                    showsMarkers: true
                )

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
        withAngles: Bool = false
    ) -> RunStatistic {
        let locations = shiftedLocations(from: startDate, speedMultiplier: speedMultiplier)
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
            startDate: startDate,
            endDate: locations.last?.timestamp ?? startDate.addingTimeInterval(runTime * 60),
            topSpeed1s: topSpeed + 1.4,
            topSpeed10s: topSpeed - 4.2,
            popUps: 7,
            percentageOnFoil: 88.7,
            turnsCount: 808
        )
        statistic.averageHeartRate = 131
        statistic.locationString = locationString
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

        return [
            statistic(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC") ?? UUID(),
                name: "DW SUP Foil",
                startDate: date(year: 2025, month: 1, day: 28, hour: 15, minute: 10),
                locationString: "Neuenburg -> St-Blaise",
                runTime: 22.83,
                distance: 5320,
                topSpeed: 24,
                averageSpeed: 14,
                tags: ["#850S"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 0.78
            ),
            statistic(
                id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD") ?? UUID(),
                name: "DW SUP Foil",
                startDate: date(year: 2025, month: 1, day: 28, hour: 12, minute: 46),
                locationString: "Concise → St-Blaise",
                runTime: 107,
                distance: 30930,
                topSpeed: 29,
                averageSpeed: 17,
                tags: ["#850S"],
                workoutType: .downwindSUPFoil,
                speedMultiplier: 1.02
            ),
            statistic(
                id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE") ?? UUID(),
                name: "DW Parawing",
                startDate: date(year: 2025, month: 1, day: 2, hour: 12, minute: 7),
                locationString: "Saint-Aubin-Sauges",
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
        manager.tags = uniqueStrings(stats.flatMap { $0.tags ?? [] })
        manager.locationStrings = uniqueStrings(stats.compactMap(\.locationString))
        manager.workoutUsageCount = Dictionary(grouping: stats.compactMap(\.workoutType), by: { $0 }).mapValues(\.count)
        manager.updateGroupedRunArray()
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

        if let liveBundle {
            manager.dashboards = liveBundle.dashboards
            manager.widgetDashboardIds = liveBundle.widgetDashboardIds
            return manager
        }

        let updated = date(year: 2025, month: 1, day: 28, hour: 14, minute: 41)
        let bielerseeURL = "https://wind.example/bielersee"
        let neuchURL = "https://wind.example/neuchatel"

        manager.dashboards = [
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
                name: "Lac de Neuchatel",
                elements: [
                    trackedElement(url: neuchURL, label: "Yverdon Avg", value: "0.0 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yverdon Gust", value: "0.0 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yverdon Dir", value: "-", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Avg", value: "4.3 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Gust", value: "7.0 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Yv Dir", value: "ENE", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Avg", value: "12.0 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Gust", value: "13.0 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Concise Dir", value: "NE", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Avg", value: "1.7 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Gust", value: "2.6 kn", updated: updated),
                    trackedElement(url: neuchURL, label: "Estavayer Dir", value: "NNE", updated: updated)
                ]
            )
        ]
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
        bestMapStatistic() ?? featuredStatistic(id: liveBundle?.featured.mapRunID) ?? statistic(
            id: UUID(uuidString: "23232323-2323-2323-2323-232323232323") ?? UUID(),
            name: "Simple Route",
            startDate: date(year: 2025, month: 3, day: 7, hour: 11, minute: 29),
            locationString: "Neuenburg -> St-Blaise",
            runTime: 64,
            distance: 14520,
            topSpeed: 27.5,
            averageSpeed: 13.6,
            tags: ["#simple", "#map"],
            workoutType: .downwindSUPFoil,
            speedMultiplier: 0.92
        )
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
        return ["Saint-Aubin-Sauges -> St-Blaise", "Only sessions with angles"]
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
        let candidateURLs = bundledCandidateURLs + unbundledCandidateURLs(in: sourceDirectory)

        for url in candidateURLs where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let bundle = try? decoder.decode(ScreenshotFakeDataBundle.self, from: data) {
                return bundle
            }
        }

        return nil
    }

    private static func unbundledCandidateURLs(in sourceDirectory: URL) -> [URL] {
        guard shouldLoadUnbundledFixture else { return [] }

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
        let startDate = run.startLocation?.timestamp ?? run.locations.first?.timestamp ?? .now
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
        statistic.locationString = edit?.locationString ?? run.locationString
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

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }
}

struct ScreenshotDashboardHomeView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeHomeManager(showTracker: false)
    @StateObject private var manager = ScreenshotSampleData.makeDashboardManager()

    var body: some View {
        StartView(
            downwindManager: downwindManager,
            initialDashboardManager: manager
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

    var body: some View {
        NavigationStack {
            GroupedTagsListView(
                downwindManager: downwindManager,
                initialLocation: "",
                initialShowOnlyAngles: false,
                initialTab: .locations
            )
        }
    }
}

struct ScreenshotTagsView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        NavigationStack {
            GroupedTagsListView(
                downwindManager: downwindManager,
                initialTags: ScreenshotSampleData.highlightedTags(),
                initialTab: .tags
            )
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
            initialDashboardManager: manager
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
            initialDashboardManager: manager
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
        }
    }
}

struct ScreenshotEditRouteView: View {
    @StateObject private var downwindManager = ScreenshotSampleData.makeDownwindManager()

    var body: some View {
        NavigationStack {
            ScreenshotStatisticContainer(
                downwindManager: downwindManager,
                statisticID: ScreenshotSampleData.mapStatistic().id
            ) { statistic in
                EditMap(downwindManager: downwindManager, statisticsData: statistic)
                    .overlay(alignment: .topLeading) {
                        ScreenshotEditMenuOverlay()
                            .padding(.top, 140)
                            .padding(.leading, 26)
                    }
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
            initialImportedRuns: ScreenshotSampleData.gpxImportRuns()
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

            Text("Last updated just now")
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

                        Text(statisticsData.locationString ?? "Neuenburg -> St-Blaise")
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
            Text("2025")
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
#endif
