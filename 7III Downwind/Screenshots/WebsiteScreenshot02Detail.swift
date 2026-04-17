#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct WebsiteScreenshot02Detail: View, AppScreenshot {
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
            phoneColorScheme: .dark
        ) {
            ScreenshotStatsDetailView()
        }
    }
}

#Preview {
    WebsiteScreenshot02Detail.preview()
}
#endif
