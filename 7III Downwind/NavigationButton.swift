//
//  NavigationButton.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.08.2025.
//

import SwiftUI

struct NavigationButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    var onHideRequest: (() -> Void)?
    
    @State private var isLongPressing = false
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                HStack {
                    Spacer()
                }
                Group {
                    if systemImage == "GPX" {
                        Text("GPX")
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: systemImage)
                            .font(.title)
                    }
                }
                .frame(minHeight: 32)
                
                Text(title)
                    .font(.headline)
            }
            .fontDesign(.rounded)
            .padding(8)
            .foregroundStyle(.white)
            .background {
                if #available(iOS 26.0, *) {
                    ConcentricRectangle(
                        corners: .concentric,
                        isUniform: true
                    )
                    .fill(color)
                    .containerShape(
                                .rect(cornerRadius: 24)
                            )
                } else {
                    RoundedRectangle(cornerRadius: 10.0)
                        .fill(color)
                }
  
            }
            .opacity(isLongPressing ? 0.5 : 1.0)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0)
                .onChanged { pressing in
                    withAnimation {
                        isLongPressing = pressing
                    }
                    if pressing {
                        if let onHideRequest = onHideRequest {
                            #if os(iOS)
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            #endif
                            onHideRequest()
                        }
                    }
                }
        )
    }
}

#Preview {
    HStack {
        NavigationButton(title: "Statistics", systemImage: "chart.xyaxis.line", color: .blue, action: {})
        NavigationButton(title: "Dashboards", systemImage: "gauge.open.with.lines.needle.33percent", color: .green, action: {})
        NavigationButton(title: "Import Run", systemImage: "GPX", color: .blue, action: {})
    }
    .padding()
    
}
