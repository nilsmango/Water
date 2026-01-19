//
//  SpeedChartView.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.10.2025.
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SpeedChartView: View {
    let data: [LocationData]

    @State private var selectedIndex: Int? = nil
    @GestureState private var dragLocation: CGPoint? = nil
    @Binding var zoom: CGFloat
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
            
            GeometryReader { geo in
                let speeds = data.compactMap { $0.speed ?? 0 }
                let maxSpeed = (speeds.max() ?? 1) * 3.6 + 5 // km/h
                let minTime = data.first?.timestamp.timeIntervalSince1970 ?? 0
                let maxTime = data.last?.timestamp.timeIntervalSince1970 ?? 1
                let totalDuration = maxTime - minTime

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack {
                        // Line
                        Path { path in
                            for (i, loc) in data.enumerated() {
                                guard let speed = loc.speed else { continue }
                                let normalizedTime = (loc.timestamp.timeIntervalSince1970 - minTime) / totalDuration
                                let x = normalizedTime * (geo.size.width * zoom)
                                let y = geo.size.height * (1 - CGFloat((speed * 3.6) / maxSpeed)) - 5

                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(.accent, lineWidth: 2)

                        // Dots
                        ForEach(Array(data.enumerated()), id: \.offset) { (i, loc) in
                            if let speed = loc.speed {
                                if i == selectedIndex {
                                    let normalizedTime = (loc.timestamp.timeIntervalSince1970 - minTime) / totalDuration
                                    let x = normalizedTime * (geo.size.width * zoom)
                                    let y = geo.size.height * (1 - CGFloat((speed * 3.6) / maxSpeed)) - 5

                                    Circle()
                                        .fill(i == selectedIndex ? Color.red : .orange)
                                        .frame(width: 8, height: 8)
                                        .position(x: x, y: y)
                                        .zIndex(i == selectedIndex ? 1 : 0)
                                }
                                
                            }
                        }

                        // Tooltip
                        if let selectedIndex,
                           let speed = data[selectedIndex].speed {
                            let loc = data[selectedIndex]
                            let normalizedTime = (loc.timestamp.timeIntervalSince1970 - minTime) / totalDuration
                            let x = normalizedTime * (geo.size.width * zoom)
                            let y = geo.size.height * (1 - CGFloat((speed * 3.6) / maxSpeed))
                            let kmSpeed = speed * 3.6
                            
                            if x < 33 {
                                VStack(alignment: .center) {
                                    HStack(alignment: .center, spacing: 4) {
                                        Rectangle()
                                            .fill(.red)
                                            .frame(width: 15, height: 1)
                                        
                                        Text(String(format: "%.1f km/h", kmSpeed))
                                            .font(.caption)
                                            .padding(5)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                }
                                .position(x: x + 40, y: y - 5)
                            } else if x > ((geo.size.width * zoom) - 33.0) {
                                VStack(alignment: .center) {
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.1f km/h", kmSpeed))
                                            .font(.caption)
                                            .padding(5)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                        
                                        Rectangle()
                                            .fill(.red)
                                            .frame(width: 15, height: 1)
                                        
                                    }
                                }
                                .position(x: x - 40, y: y - 5)
                            } else {
                                VStack(spacing: 4) {
                                    if y - 25 > 25 {
                                        Text(String(format: "%.1f km/h", kmSpeed))
                                            .font(.caption)
                                            .padding(5)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                        Rectangle()
                                            .fill(.red)
                                            .frame(width: 1, height: 15)
                                    } else {
                                        Rectangle()
                                            .fill(.red)
                                            .frame(width: 1, height: 15)
                                        
                                        Text(String(format: "%.1f km/h", kmSpeed))
                                            .font(.caption)
                                            .padding(5)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                        
                                    }
                                    
                                }
                                .position(x: x, y: y - 25 > 25 ? y - 25 : y + 15)
                            }
                            
                            
                            
                        }
                    }
                    .frame(width: geo.size.width * zoom, height: geo.size.height)
                    .id("chart")
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: -geo.frame(in: .named("scroll")).minX)
                        }
                    )

                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragLocation) { value, state, _ in
                                state = value.location
                                let relativeX = value.location.x / (geo.size.width * zoom)
                                let time = minTime + totalDuration * Double(relativeX)

                                // find nearest dot
                                if let idx = data.enumerated().min(by: {
                                    abs($0.element.timestamp.timeIntervalSince1970 - time) <
                                    abs($1.element.timestamp.timeIntervalSince1970 - time)
                                })?.offset {
                                    selectedIndex = idx
                                }
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = max(0, value)
                }
                .onChange(of: zoom) { oldValue, newValue in
                    let contentCenter = (scrollOffset + geo.size.width / 2) * (newValue / oldValue)
                    let newOffset = max(0, contentCenter - geo.size.width / 2)
                    let newContentWidth = geo.size.width * newValue
                    let anchor = max(0, min(1, newOffset / newContentWidth))
                    proxy.scrollTo("chart", anchor: UnitPoint(x: anchor, y: 0))
                }
            }
            .frame(height: 200)
        }
    }
}

#Preview {
    SpeedChartView(data: decodeLocationSampleData() ?? Constants.locationSampleData, zoom: .constant(2))
        .frame(height: 100)
}
