#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone08StatisticsOverview: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 908,
            titleLines: ["With", "Statistics"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotStatisticsOverviewView()
        }
    }
}

#Preview {
    Phone08StatisticsOverview.preview()
}
#endif
