//
//  _III_DownwindApp.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import SwiftUI

@main
struct _III_DownwindApp: App {
    @StateObject private var downwindManager = DownwindManager()
    
    @State private var showOpenURLDialog = false
    @State private var runToJoin = ""
    
    @State private var showAlert = false
    @State private var alertText = ""
    
    var body: some Scene {
        WindowGroup {
            StartView(downwindManager: downwindManager)
                .onAppear {
                    downwindManager.loadUser()
                    downwindManager.checkHealthKitAuthorizationStatus()
                    downwindManager.loadRunStatistics()
                    downwindManager.loadErrorLog()
                    Task {
                        await downwindManager.updateCustomerProductStatus()
                    }
                }
        }
    }
}
