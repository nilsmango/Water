//
//  BearingArrowView.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.01.24.
//

import SwiftUI

struct BearingArrowView: View {
    var degrees: Double
    
    var body: some View {
//        GeometryReader { geometry in
            Image(systemName: "arrow.up")
                .resizable()
                .scaledToFit()
                .rotationEffect(Angle(degrees: degrees))
//                .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
//                    .onTapGesture {
//                        withAnimation {
//                            degrees += 45.0
//                        }
//                    }
                }
        }
//    }

#Preview {
    BearingArrowView(degrees: 20)
}
