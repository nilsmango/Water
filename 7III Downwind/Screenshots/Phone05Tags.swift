#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone05Tags: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 515,
            titleLines: ["Powerful", "Tags"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            ScreenshotTagsView()
        }
    }
}

#Preview {
    Phone05Tags.preview()
}
#endif
