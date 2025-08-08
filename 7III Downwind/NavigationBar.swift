//
//  NavigationBar.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.08.2025.
//

import SwiftUI

struct NavigationBar: View {
    let showGPX: Bool
    let isLoadingImportedRuns: Bool
    @Binding var isImporting: Bool
    let navigateToStats: () -> Void
    let navigateToDashboard: () -> Void
    
    var body: some View {
        HStack {
            NavigationButton(title: "Statistics", systemImage: "chart.xyaxis.line", color: .accent) {
                navigateToStats()
            }
            NavigationButton(title: "Dashboards", systemImage: "gauge.open.with.lines.needle.33percent", color: .accent) {
                navigateToDashboard()
            }
            if showGPX {
                NavigationButton(title: "Import Runs", systemImage: "GPX", color: isLoadingImportedRuns ? .gray.opacity(0.5) : .accent) {
                    if !isLoadingImportedRuns {
                        isImporting = true
                    }
                }
                .disabled(isLoadingImportedRuns)
            }
            
        }
        .padding()
    }
}

#Preview {
    NavigationBar(showGPX: true, isLoadingImportedRuns: false, isImporting: .constant(false), navigateToStats: {}, navigateToDashboard: {})
}
