//
//  RunUITest.swift
//  7III Downwind
//
//  Created by Simon Lang on 01.01.24.
//

import SwiftUI

struct RunUITest: View {
    private var runMembers = [Member(id: UUID(), name: "Fritz", latitude: 47.43, longitude: 55.4), Member(id: UUID(), name: "Franz", latitude: 48.43, longitude: 55.9), Member(id: UUID(), name: "Florian", latitude: 48.12, longitude: 55.2)]
    
    private var myself = Member(id: UUID(), name: "Nils Mango", latitude: 48.1206, longitude: 55.202)
    
    var body: some View {
                   Canvas { context, size in

                       // Calculate the center of the screen
                       let centerX = size.width / 2
                       let centerY = size.height / 2

                       // Draw a circle in the center
                       let radius: CGFloat = 10
                       let circleRect = CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2)
                       context.fill(Circle().path(in: circleRect), with: .color(.black))
                       
                       // Calculate canvas in meter
                       let CGFloatPerMeter = size.height / Constants.heightOfMap
                       let widthOfMap = size.width * CGFloatPerMeter
                       
                       
                       // Draw each of the Members
                       for member in runMembers {
                           
                           // Calculate the RelativePosition
                           let relativePos = calculateMemberRunData(of: member, to: myself)
                           
                           // Calculate if RelativePosition is inside the canvas view
                           let isInsideCanvas = isPosInside(position: relativePos, canvasWidth: widthOfMap, canvasHeight: Constants.heightOfMap)
                           
//                           print(isInsideCanvas)
                           
                           if isInsideCanvas {
                               // Draw circle, with short name and direct distance
                               let circleRect = CGRect(x: relativePos.x - radius, y: relativePos.y - radius, width: radius * 5, height: radius * 5)
                               
                               context.fill(Circle().path(in: circleRect), with: .color(.blue))
                               
                               // Draw text below the circle
                               let textRect = CGRect(x: relativePos.x - radius, y: relativePos.y - radius, width: 60, height: 40)
                               let text = Text(verbatim: String(relativePos.distance.rounded()))
                                           var resolvedText = context.resolve(text)
                                           resolvedText.shading = .color(.red)
                                           context.draw(resolvedText, in: textRect)
                                             
                               
                           } else {
                               // Draw arrow at closest edge, with short name and direct distance
                               // calculate closest edge to the center, put arrow there
                           }
                       }
                   }
           
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    RunUITest()
}
