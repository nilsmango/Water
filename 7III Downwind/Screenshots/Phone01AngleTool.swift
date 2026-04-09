#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone01AngleTool: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 1901,
            titleLines: ["NEW:", "Angle Tool"],
            phoneOffsetY: 300,
            phoneColorScheme: .dark
        ) {
            ScreenshotAngleToolView()
        }
    }
}

#Preview {
    Phone01AngleTool.preview()
}
#endif
