#if os(iOS)
import Project7IIIScreenshots
import SwiftUI

struct Phone01AngleTool: View, AppScreenshot {
    nonisolated static var configuration: AppScreenshotConfiguration {
        AppScreenshotConfiguration(.iPhone69Inch(size: .w1290h2796), options: defaultScreenshotOption)
    }

    @MainActor
    static func body(environment: AppScreenshotEnvironment) -> some View {
        Self().environment(\.appScreenshotEnvironment, environment)
    }

    var body: some View {
        AppStorePhoneCanvas(
            seed: 1901,
            titleLines: ["NEW:", "Angle Tool"],
            phoneOffsetY: 300,
            phoneColorScheme: .light
        ) {
            
            // A lil fake sheet
            
            let statistic = ScreenshotSampleData.hyeresStatistic()

            ZStack {
                Color.black.opacity(0.3)

                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    ZStack {
                        NavigationStack {
                            WindSportStatisticsMap(
                                downwindManager: DownwindManager(),
                                statisticsData: .constant(statistic),
                                angleTool: true
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        
                        VStack(spacing: 0) {
                            
                            ZStack {
                                
                                Rectangle()
                                    .fill(.white.opacity(0.5))
                                    .frame(width: 80, height: 40)
                                    .blur(radius: 5)
                                
                                Text("Hyères")
                                    .bold()
                                
                                HStack {
                               
                                    Spacer()
                                    
                                    if #available(iOS 26.0, *) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.primary)
                                            .padding(12)
                                            .glassEffect()
                                    } else {
                                        // Fallback on earlier versions
                                    }
                                }
                            }
                            .padding()
                            
                            Spacer()

                        }
                    }
                    
                }
                
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    Phone01AngleTool.preview()
}
#endif
