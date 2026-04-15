#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone11StatsDetail: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1111,
            titleLines: ["So many", "Stats!"],
            phoneOffsetY: 300,
            phoneColorScheme: .dark
        ) {
            ScreenshotStatsDetailView()
        }
    }
}

#Preview {
    Phone11StatsDetail.preview()
}
#endif
