#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone03Export: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 923,
            titleLines: ["Video, Photo", "& GPX Export"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            let downwindManager = ScreenshotSampleData.makeDownwindManager()
            ZStack {
                NavigationStack {
                    ScreenshotStatisticContainer(
                        downwindManager: downwindManager,
                        statisticID: ScreenshotSampleData.exportStatistic().id
                    ) { statistic in
                        StatisticsRunView(downwindManager: downwindManager, statisticsData: statistic, noToolbar: true)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {} label: {
                                        Image(systemName: "chevron.left")
                                    }
                                }
                            }
                    }
                }
                
                VStack() {
                    HStack {
                        Spacer()
                        
                        FakeMenu(items: [FakeMenuItem(title: "Video", icon: "film"), FakeMenuItem(title: "Map Photo", icon: "photo"), FakeMenuItem(title: "Sticker Overlay", icon: "square.dashed"), FakeMenuItem(title: "GPX", icon: "point.bottomleft.forward.to.point.topright.scurvepath")])
                        
                    }
                    
                    
                    Spacer()
                }
                
            
            
            }
        }
    }
}

#Preview {
    Phone03Export.preview()
}
#endif
