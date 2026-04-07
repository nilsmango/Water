#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone02Dashboards: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 202,
            titleLines: ["NEW:", "Dashboards"],
            phoneOffsetY: 310,
            phoneColorScheme: .light
        ) {
            ScreenshotDashboardHomeView()
        }
    }
}

#Preview {
    Phone02Dashboards.preview()
}
#endif
