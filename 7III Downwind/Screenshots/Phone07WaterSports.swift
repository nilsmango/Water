#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone07WaterSports: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 707,
            titleLines: ["For all Water", "Sports"],
            phoneOffsetY: 350,
            phoneColorScheme: .light
        ) {
            ScreenshotWaterSportsView()
        }
    }
}

#Preview {
    Phone07WaterSports.preview()
}
#endif
