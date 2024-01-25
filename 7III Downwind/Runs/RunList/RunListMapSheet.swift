//
//  RunListMapSheet.swift
//  7III Downwind
//
//  Created by Simon Lang on 25.01.2024.
//

import SwiftUI

struct RunListMapSheet: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var isShowingSheet: Bool
    
    
    var body: some View {
        MapView(members: downwindManager.activeRun.members, user: downwindManager.user, measurementSystem: downwindManager.measurementSystem, onlyWatching: false, isShowingSheet: $isShowingSheet, heading: downwindManager.trueHeading)
    }
}

#Preview {
    RunListMapSheet(downwindManager: DownwindManager(), isShowingSheet: .constant(true))
}
