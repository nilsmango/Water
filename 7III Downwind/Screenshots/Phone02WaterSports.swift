#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone02WaterSports: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 707,
            titleLines: ["For all Water", "Sports"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            let downwindManager = ScreenshotSampleData.makeHomeManager(
                showTracker: true,
                workoutType: .downwindSUPFoil
            )
            let manager = ScreenshotSampleData.makeDashboardManager()

            StartView(
                downwindManager: downwindManager,
                initialDashboardManager: manager,
                animateDashboardDirectionArrows: false
            )
            .overlay(alignment: .topTrailing) {
                FakePicker(items: [
                    "Foil Surf",
                    "SUP Foil",
                    "DW SUP Foil",
                    "DW SUP",
                    "DW Prone Foil",
                    "Wing Foil",
                    "Parawing",
                    "DW Parawing",
                    "Wind Foil",
                    "Kite Foil",
                    "Kite",
                    "Windsurf",
                    "Pump Foil",
                    "Wake Thief",
//                    "Wake Foil",
//                    "Wake Surf"
                ], selected: "DW SUP Foil")
                .padding(.top, 218)
                .padding(.trailing, 30)
            }
        }
    }
}

#Preview {
    Phone02WaterSports.preview()
}
#endif
