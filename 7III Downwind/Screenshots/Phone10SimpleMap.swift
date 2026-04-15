#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone10SimpleMap: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1210,
            titleLines: ["Beautiful", "& Simple"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotSimpleMapView()
        }
    }
}

#Preview {
    Phone10SimpleMap.preview()
}
#endif
