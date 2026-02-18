//
//  MapsMenuView.swift
//  7III Downwind
//
//  Created by Simon Lang on 18.02.26.
//

import SwiftUI

struct MapsMenuView: View {
    @Binding var navPath: NavigationPath
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                NavigationButton(title: "Activities per Year", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath", color: .accent) {
                    navPath.append(NavDestination.allRunsMap)
                }
                
                NavigationButton(title: "Spots", systemImage: "mappin.and.ellipse", color: .accent) {
                    navPath.append(NavDestination.spots)
                }
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("Maps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MapsMenuView(navPath: .constant(NavigationPath()))
    }
}
