#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

/// Review-only capture of the difficult 18 September GPX. Kept separate from
/// the App Store screenshot so new test routes cannot replace promotional art.
struct TestWindAnalysisSeptember18: View, AppScreenshot {
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
            ScreenshotWindAnalysisView(
                fixtureName: "carqueiranne-2026-09-18",
                expectedCount: 6_064,
                startTimestamp: 1_789_747_436,
                windFromBearing: 310,
                workoutType: .paraUpDown
            )
        }
    }
}

/// Review-only capture of the 17 September GPX with its short tacks.
struct TestWindAnalysisSeptember17: View, AppScreenshot {
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
            ScreenshotWindAnalysisView(
                fixtureName: "carqueiranne-2026-09-17",
                expectedCount: 10_911,
                startTimestamp: 1_789_652_571,
                workoutType: .paraUpDown
            )
        }
    }
}
#endif
