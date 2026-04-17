#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone05Tags: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 515,
            titleLines: ["Powerful", "Tags"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotTagsView()
        }
    }
}

#Preview {
    Phone05Tags.preview()
}
#endif
