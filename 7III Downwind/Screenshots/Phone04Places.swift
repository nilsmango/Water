#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone04Places: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 404,
            titleLines: ["Filter by", "Places & More"],
            phoneOffsetY: 340,
            phoneColorScheme: .light
        ) {
            ScreenshotPlacesView()
        }
    }
}

#Preview {
    Phone04Places.preview()
}
#endif
