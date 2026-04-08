#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone10SimpleMap: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 1610,
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
