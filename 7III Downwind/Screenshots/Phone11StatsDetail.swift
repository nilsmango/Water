#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone11StatsDetail: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 1111,
            titleLines: ["So many", "Stats!"],
            phoneOffsetY: 300,
            phoneColorScheme: .dark
        ) {
            ScreenshotStatsDetailView()
        }
    }
}

#Preview {
    Phone11StatsDetail.preview()
}
#endif
