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
    var showUpdated: Bool
    
    @Binding var showAlert: Bool
        
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
            .frame(width: 90, height: 85)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let latitude = member.latitude, let longitude = member.longitude {
                UIPasteboard.general.string = "\(latitude), \(longitude)"
                showAlert = true
            }
        }
    }
}

#Preview {
    CircleAndText(member: Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.123295, longitude: 7.220013, speed: 1.3), measurementSystem: .metric, showUpdated: false, showAlert: .constant(false))
}
