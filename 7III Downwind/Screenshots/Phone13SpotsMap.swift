#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone13SpotsMap: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1313,
            titleLines: ["Add and find", "Foil Spots!"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotSpotsMapView()
        }
    }
}

#Preview {
    Phone13SpotsMap.preview()
}
#endif
