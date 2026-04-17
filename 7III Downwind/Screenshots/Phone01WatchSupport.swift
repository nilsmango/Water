#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone01WatchSupport: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 676,
            titleLines: ["Tracking with", "Watch Support"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            let downwindManager = ScreenshotSampleData.makeHomeManager(
                showTracker: true,
                workoutType: .downwindSUP
            )
            let manager = ScreenshotSampleData.makeDashboardManager()

            StartView(
                downwindManager: downwindManager,
                initialDashboardManager: manager,
                animateDashboardDirectionArrows: false
            )
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 24) {
                Image("appleWatch01")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    
//                Image("appleWatch02")
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
            }
            .frame(height: 1120)
            .padding(.bottom, 00)
        }
    }
}

#Preview {
    Phone01WatchSupport.preview()
}
#endif
