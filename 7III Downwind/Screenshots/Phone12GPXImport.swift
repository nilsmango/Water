#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone12GPXImport: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1212,
            titleLines: ["GPX Import:", "Garmin & More"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotGPXImportView()
        }
    }
}

#Preview {
    Phone12GPXImport.preview()
}
#endif
