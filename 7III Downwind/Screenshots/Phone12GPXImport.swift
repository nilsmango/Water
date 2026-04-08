#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone12GPXImport: View {
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
