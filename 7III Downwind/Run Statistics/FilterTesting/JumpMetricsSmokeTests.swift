import Foundation

@main
struct JumpMetricsSmokeTests {
    static func main() {
        testFlatWaterNoiseDoesNotCreateJumps()
        testBroadWaveDoesNotCreateJump()
        testPoorVerticalAccuracyDoesNotCreateJump()
        testNeedleSpikeDoesNotCreateJump()
        testSingleJumpCountsOnce()
        testTwoJumpsUseLocalBaseline()
        
        print("JumpMetricsSmokeTests passed")
    }
    
    private static func testFlatWaterNoiseDoesNotCreateJumps() {
        let locations = makeLocations(altitudes: [0.0, 0.1, -0.1, 0.1, 0.0, -0.1, 0.0])
        let metrics = calculateJumpMetrics(from: locations)
        precondition(metrics == nil, "Expected no jumps for flat-water noise, got \(String(describing: metrics))")
    }
    
    private static func testBroadWaveDoesNotCreateJump() {
        let locations = makeLocations(altitudes: [0.0, 0.4, 0.9, 1.4, 1.8, 1.5, 1.0, 0.4, 0.0])
        let metrics = calculateJumpMetrics(from: locations)
        precondition(metrics == nil, "Expected no jumps for a broad swell, got \(String(describing: metrics))")
    }

    private static func testPoorVerticalAccuracyDoesNotCreateJump() {
        let locations = makeLocations(
            altitudes: [0.0, 0.1, 0.0, 1.6, 2.5, 1.4, 0.2, 0.0],
            verticalAccuracy: 20.0
        )
        let metrics = calculateJumpMetrics(from: locations)
        precondition(metrics == nil, "Expected poor-accuracy samples to be ignored, got \(String(describing: metrics))")
    }

    private static func testNeedleSpikeDoesNotCreateJump() {
        let locations = makeLocations(altitudes: [0.0, 0.1, 0.0, 1.9, 0.2, 0.1, 0.0])
        let metrics = calculateJumpMetrics(from: locations)
        precondition(metrics == nil, "Expected a single-point spike to be ignored, got \(String(describing: metrics))")
    }
    
    private static func testSingleJumpCountsOnce() {
        let locations = makeLocations(altitudes: [0.0, 0.1, 0.0, 1.2, 2.7, 1.1, 0.1, 0.0, 0.1])
        guard let metrics = calculateJumpMetrics(from: locations) else {
            preconditionFailure("Expected a jump to be detected")
        }
        
        precondition(metrics.jumpCount == 1, "Expected 1 jump, got \(metrics.jumpCount)")
        precondition(abs(metrics.highestJump - 2.37) < 0.35, "Expected highest jump near 2.37 m, got \(metrics.highestJump)")
    }
    
    private static func testTwoJumpsUseLocalBaseline() {
        let locations = makeLocations(altitudes: [0.0, 0.1, 0.0, 1.2, 2.0, 1.1, 0.2, 0.1, 0.4, 0.6, 2.8, 0.7, 0.5])
        guard let metrics = calculateJumpMetrics(from: locations) else {
            preconditionFailure("Expected two jumps to be detected")
        }
        
        precondition(metrics.jumpCount == 2, "Expected 2 jumps, got \(metrics.jumpCount)")
        precondition(abs(metrics.highestJump - 2.46) < 0.35, "Expected highest jump near 2.46 m, got \(metrics.highestJump)")
    }
    
    private static func makeLocations(altitudes: [Double], startDate: Date = .now, verticalAccuracy: Double = 1.5) -> [LocationData] {
        altitudes.enumerated().map { index, altitude in
            LocationData(
                timestamp: startDate.addingTimeInterval(Double(index)),
                latitude: 46.0 + Double(index) * 0.00001,
                longitude: 7.0 + Double(index) * 0.00001,
                altitude: altitude,
                speed: 7.0,
                verticalAccuracy: verticalAccuracy
            )
        }
    }
}
