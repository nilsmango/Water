#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone07WaterSports: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 707,
            titleLines: ["For all Water", "Sports"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotWaterSportsView()
        }
    }
}

#Preview {
    Phone07WaterSports.preview()
}
#endif
