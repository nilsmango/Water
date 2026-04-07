#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone10SimpleMap: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 1010,
            titleLines: ["Beautiful", "& Simple"],
            phoneOffsetY: 305,
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
