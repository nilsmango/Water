#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone06WatchSupport: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 606,
            titleLines: ["Tracking with", "Watch Support"],
            phoneOffsetY: 360,
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
