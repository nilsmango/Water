//
//  HeadingIndicator.swift
//  7III Downwind
//
//  Created by Simon Lang on 25.01.2024.
//

import SwiftUI

struct HeadingIndicator: View {
    var heading: Double
    
    var body: some View {
        Cone()
            .fill(LinearGradient(
                gradient: Gradient(colors: [.clear, .clear, .clear, .blue.opacity(0.75)]),
                                startPoint: .top,
                                endPoint: .center
                            ))
            .rotationEffect(.degrees(heading))
            .frame(width: 50, height: 175)
    }
}

#Preview {
    HeadingIndicator(heading: 180.2)
}


struct Cone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}
