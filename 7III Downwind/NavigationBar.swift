//
//  NavigationBar.swift
//  7III Tracker
//
//  Created by Simon Lang on 07.08.2025.
//

import SwiftUI

struct NavigationBar: View {
    let showGPX: Bool
    let showMaps: Bool
    let isLoadingImportedRuns: Bool
    @Binding var isImporting: Bool
    let navigateToStats: () -> Void
    let navigateToDashboard: () -> Void
    let navigateToMaps: () -> Void
    let removeGPXButton: () -> Void
    
    private var buttonCount: Int {
        var count = 2
        if showGPX { count += 1 }
        if showMaps { count += 1 }
        return count
    }
    
    private var showTwoLines: Bool {
        buttonCount > 3
    }
    
    var body: some View {
        if showTwoLines {
            VStack(spacing: 8) {
                firstRow
                secondRow
            }
            .padding()
        } else {
            HStack {
                rowButtons
            }
            .padding()
        }
    }
    
    private var firstRow: some View {
        HStack(spacing: 12) {
            NavigationButton(title: "Statistics", systemImage: "chart.xyaxis.line", color: .accent, action: navigateToStats)
            if showMaps {
                NavigationButton(title: "Maps", systemImage: "map", color: .accent, action: navigateToMaps)
            }
        }
    }
    
    private var secondRow: some View {
        HStack(spacing: 12) {
            NavigationButton(title: "Dashboards", systemImage: "gauge.open.with.lines.needle.33percent", color: .accent, action: navigateToDashboard)
            if showGPX {
                NavigationButton(title: "Import Runs", systemImage: "GPX", color: isLoadingImportedRuns ? .gray.opacity(0.5) : .accent, action: {
                    if !isLoadingImportedRuns {
                        isImporting = true
                    }
                })
                .contextMenu {
                    Button {
                        removeGPXButton()
                    } label: {
                        Label("Remove", systemImage: "eye.slash.fill")
                    }
                    Label("You can add the button back in Settings", systemImage: "info.circle")
                }
                .disabled(isLoadingImportedRuns)
            }
        }
    }
    
    private var rowButtons: some View {
        Group {
            NavigationButton(title: "Statistics", systemImage: "chart.xyaxis.line", color: .accent, action: navigateToStats)
            NavigationButton(title: "Dashboards", systemImage: "gauge.open.with.lines.needle.33percent", color: .accent, action: navigateToDashboard)
            
            if showMaps {
                NavigationButton(title: "Maps", systemImage: "map", color: .accent, action: navigateToMaps)
            }
            
            if showGPX {
                NavigationButton(title: "Import Runs", systemImage: "GPX", color: isLoadingImportedRuns ? .gray.opacity(0.5) : .accent, action: {
                    if !isLoadingImportedRuns {
                        isImporting = true
                    }
                })
                .contextMenu {
                    Button {
                        removeGPXButton()
                    } label: {
                        Label("Remove", systemImage: "eye.slash.fill")
                    }
                    Label("You can add the button back in Settings", systemImage: "info.circle")
                }
                .disabled(isLoadingImportedRuns)
            }
        }
    }
}

#Preview {
    NavigationBar(showGPX: true, showMaps: true, isLoadingImportedRuns: false, isImporting: .constant(false), navigateToStats: {}, navigateToDashboard: {}, navigateToMaps: {}, removeGPXButton: {})
}
