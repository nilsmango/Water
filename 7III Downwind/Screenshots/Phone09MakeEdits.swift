#if os(iOS)
import AppScreenshotKit
import SwiftUI

@AppScreenshot(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
struct Phone09MakeEdits: View {
    var body: some View {
        AppStorePhoneCanvas(
            seed: 909,
            titleLines: ["Make Edits"],
            phoneOffsetY: 305,
            phoneColorScheme: .dark
        ) {
            ScreenshotEditRouteView()
        }
    }
}

#Preview {
    Phone09MakeEdits.preview()
}
#endif
