#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone01AngleTool: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1901,
            titleLines: ["NEW:", "Angle Tool"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotHyeresAngleToolView()
        }
    }
}

#Preview {
    Phone01AngleTool.preview()
}
#endif
