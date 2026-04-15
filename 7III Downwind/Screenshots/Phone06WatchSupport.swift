#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone06WatchSupport: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 676,
            titleLines: ["Tracking with", "Watch Support"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotWatchSupportView()
        }
    }
}

#Preview {
    Phone06WatchSupport.preview()
}
#endif
