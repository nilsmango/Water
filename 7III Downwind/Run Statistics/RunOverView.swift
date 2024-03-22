//
//  RunOverView.swift
//  7III Downwind
//
//  Created by Simon Lang on 17.03.2024.
//

import SwiftUI

struct RunOverView: View {
    let runDate: String
    let runName: String
    let distance: String
    let time: String
    let averageSpeed: String
    
    var body: some View {
        VStack {
            HStack {
                    Text(runDate)
                        .fontWeight(.bold)
                
                    Text(runName)
                
                Spacer()
            }
            HStack {
                Text(distance)
                Text(time)
                Text(averageSpeed)
                Spacer()
            }
        }
        
    }
}

#Preview {
    List {
        RunOverView(runDate: "2024-03-02", runName: "Testrun", distance: "21 km", time: "1.3 h", averageSpeed: "15 km/h")
    }
    
}
