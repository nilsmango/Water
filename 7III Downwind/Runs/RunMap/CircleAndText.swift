//
//  CircleAndText.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2024.
//

import SwiftUI

struct CircleAndText: View {
    var member: Member
    var measurementSystem: MeasurementSystem
        
    @State private var showUpdated = false
    
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 20)
                .foregroundStyle(.secondary)
            
            VStack {
                Spacer()
                
                if showUpdated {
                    Text("Last updated:")
                    if let dateString = member.lastUpdated {
                        let date = dateFromString(dateString)
                        Text(date!, style: .timer)
                            .monospacedDigit()
                    } else {
                        Text("unknown")
                    }
                    
                    
                } else {
                    Text(member.name)
                        
                    if let speed = member.speed {
                        Text(makePrettySpeed(speed: speed, system: measurementSystem))
                    } else {
                        Text(measurementSystem == .imperial ? "- mph" : "- km/h")
                    }
                }
                
            }
            .font(.caption)
            .frame(width: 90, height: 90)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showUpdated.toggle()
        }
    }
}

#Preview {
    CircleAndText(member: Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.123295, longitude: 7.220013, speed: 1.3), measurementSystem: .metric)
}
