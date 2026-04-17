#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct WebsiteScreenshot01Overview: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        WebsitePhoneCanvas(
            phoneOffsetY: 0,
            phoneColorScheme: .light
        ) {
            ScreenshotStatisticsOverviewView()
        }
    }
}

#Preview {
    WebsiteScreenshot01Overview.preview()
}
#endif
