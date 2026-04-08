#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone03Export: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 923,
            titleLines: ["Video, Photo", "& GPX Export"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotExportRunView()
        }
    }
}

#Preview {
    Phone03Export.preview()
}
#endif
