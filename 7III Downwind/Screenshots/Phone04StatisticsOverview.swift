#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone04StatisticsOverview: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 908,
            titleLines: ["Awesome", "Statistics!"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotStatisticsOverviewView()
        }
    }
}

#Preview {
    Phone04StatisticsOverview.preview()
}
#endif
