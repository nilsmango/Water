//
//  ShareOverlay.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.07.2024.
//

import SwiftUI
import MapKit

struct ShareOverlay: View {
    var sport: String
    var distance: String
    var time: String
    var extraTitle: String
    var extraValue: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0.0) {

            Spacer()
            
            Text("7III Water")
                .foregroundStyle(.white)
                .font(.title2)
                .fontWeight(.bold)
                .shadow(color: .black.opacity(0.4),radius: 5)
                .padding(.trailing, 16)
            
            HStack {
                
                Spacer()
                
                HStack(alignment: .bottom) {
                                        
                    ShareStatStack(title: sport, value: distance)
                    
                    Divider()
                        .frame(height: 35)
                        .background(.white)
                    
                    ShareStatStack(title: "Time", value: time)
                    
                    Divider()
                        .frame(height: 35)
                        .background(.white)
                    
                    ShareStatStack(title: extraTitle, value: extraValue)
                        
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.black)
                        .opacity(0.7)
                }
                .padding(8)
                .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ZStack {
        Map()
        
            ShareOverlay(sport: "DW SUP Foil", distance: "12.4 km", time: "3:31", extraTitle: "∅-Pace", extraValue: "3:00 /km")
        
    }
    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
    
}
