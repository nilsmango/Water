#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone08Places: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 704,
            titleLines: ["Filter by", "Places & more"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotPlacesView()
        }
    }
}

#Preview {
    Phone08Places.preview()
}
#endif
