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
                    Task {
                        await downwindManager.updateCustomerProductStatus()
                    }
                }
                .overlay {
                    OverlayAlertView(showAlert: $showAlert, text: alertText)
                }
                .confirmationDialog("Opening this run to:", isPresented: $showOpenURLDialog, actions: {
                    Button("Join") {
                        Task {
                            do {
                                try await downwindManager.joinRun(name: runToJoin)
                            } catch GetRunError.badResponse {
                                alertText = "No run with the name \"\(runToJoin)\" found!"
                                showAlert = true
                            } catch {
                                alertText = "Error joining run: \(error)"
                                showAlert = true
                            }
                        }
                    }
                    Button("Watch") {
                        Task {
                            do {
                                try await downwindManager.watchRun(name: runToJoin)
                            } catch GetRunError.badResponse {
                                alertText = "No run with the name \"\(runToJoin)\" found!"
                                showAlert = true
                            } catch {
                                alertText = "Error joining run: \(error)"
                                showAlert = true
                            }
                        }
                    }
                })
                .onOpenURL(perform: { url in
                    // show overlay to ask if you want to join or watch the run. give it the url too.
                    showOpenURLDialog = true
                    runToJoin = makeURLToRunName(url: url)
                    
                })
        }
    }
}
