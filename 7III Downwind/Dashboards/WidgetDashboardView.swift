//
//  WidgetDashboardView.swift
//  7III Tracker
//
//  Created by Simon Lang on 09.08.2025.
//

import SwiftUI

struct WidgetDashboardView: View {
    @ObservedObject var manager: TrackedElementsManager
    @ObservedObject var downwindManager: DownwindManager
    let dashboard: Dashboard
    @Binding var navPath: NavigationPath
    
    let widgetPadding = 8.0
    @State private var tapOpacity: Double = 1
    
    var body: some View {
        
        Text(dashboard.name)
            .font(.headline)
            .padding(widgetPadding/2)
        // CONTENT SECTION
                if dashboard.elements.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "globe")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Elements Tracked")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal)
                        
                } else {
                    
                    let nestedElements = manager.makeNestedElements(from: dashboard.elements)
                    
                    VStack(spacing: widgetPadding*1.5) {
                            ForEach(nestedElements, id: \.self) { elements in
                                let doNotShow = !downwindManager.hasPurchasedPremium && nestedElements.firstIndex(of: elements) != 0
                                let doNotShowButton = !downwindManager.hasPurchasedPremium && nestedElements.firstIndex(of: elements) ?? 2 > 1
                                
                                if doNotShowButton {
                                    
                                } else if doNotShow {
                                    Button {
                                        downwindManager.showUpgradeSheet = true
                                    } label: {
                                        Label("Unlock unlimited Dashboards", systemImage: "lock.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .padding(.horizontal)
                                    .padding(.top, elements == nestedElements.first ? 0 : widgetPadding/2)
                                } else {
                                    let row = manager.makeNestedElementsRow(elements: elements)
                                    let element: TrackedElement? = elements.count == 1 ? elements[0] : nil
                                        NestedElementsRow(label: row.label, url: row.url, error: row.error, rowText: row.rowText, directionDegrees: row.directionDegrees, element: element, dashboardIndex: nil, manager: manager, onExpand: {}, onEdit: {}, onDuplicate: {})
                                        .padding(.horizontal)
                                        .padding(.top, elements == nestedElements.first ? 0 : widgetPadding/2)
                                }                                    
                            }
                        }
                        .padding(.vertical, widgetPadding*1.5)
                        .background {
                            ListBackground()
                        }
                        .opacity(tapOpacity)
                        .onTapGesture {
                                tapOpacity = 0.5
                                    withAnimation {
                                        tapOpacity = 1
                                    }
                            if manager.refreshmentStatus == nil {
                                if manager.showWidgetTap {
                                    manager.showWidgetTap = false
                                }
                                Task {
                                    await manager.refreshDashboard(dashboard: dashboard)
                                }
                            }
                        }
                        .contextMenu {
                            Button {
                                manager.toggleWidgetEnabled(dashboardId: dashboard.id)
                            } label: {
                                Label("Remove", systemImage: "pin.slash.fill")
                            }
                            
                            Button {
                                navPath = NavigationPath()
                                navPath.append(NavDestination.dashboards)
                                navPath.append(NavDestination.dashboard(dashboard))
                                
                            } label: {
                                Label("Go to Dashboard", systemImage: "gauge.open.with.lines.needle.33percent")
                            }
                            
                            if manager.widgetDashboardIds.count > 1 {
                                if manager.canMoveWidgetUp(dashboardId: dashboard.id) {
                                    Button {
                                        manager.moveWidgetUp(dashboardId: dashboard.id)
                                    } label: {
                                        Label("Move Up", systemImage: "arrow.up")
                                    }
                                }
                                if manager.canMoveWidgetDown(dashboardId: dashboard.id) {
                                    Button {
                                        manager.moveWidgetDown(dashboardId: dashboard.id)
                                    } label: {
                                        Label("Move Down", systemImage: "arrow.down")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                }
        
        // Header
        Group {
            if let status = manager.widgetRefreshmentStatus {
                Text(status)
            } else if let updated = dashboard.elements.first?.lastUpdated {
                if manager.showWidgetTap {
                    Text("Tap list to refresh. Last updated: \(Text(updated, style: .relative)) ago.")
                } else {
                    Text("Last updated: \(Text(updated, style: .relative)) ago.")
                }
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.horizontal)
        .padding(.bottom, widgetPadding)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .font(.caption)
        
    }
}

#Preview {
    ScrollView {
        VStack {
            WidgetDashboardView(manager: TrackedElementsManager(), downwindManager: DownwindManager(), dashboard: Dashboard(name: "Bielersee", elements: [TrackedElement(url: "example.com", xpath: "", userLabel: "Hafen", lastValue: "20 kn", lastUpdated: Date(), lastError: nil), TrackedElement(url: "example.com", xpath: "", userLabel: "Hafen", lastValue: "32 kn", lastUpdated: Date(), lastError: nil), TrackedElement(url: "example.com", xpath: "", userLabel: "Hafen", lastValue: "NW", lastUpdated: Date(), lastError: nil), TrackedElement(url: "example.com", xpath: "", userLabel: "Vinguelz", lastValue: "32 kn", lastUpdated: Date(), lastError: nil), TrackedElement(url: "example.com", xpath: "", userLabel: "Birke", lastValue: "20 kn", lastUpdated: Date(), lastError: nil), TrackedElement(url: "example.com", xpath: "", userLabel: "BItch", lastValue: "20 kn", lastUpdated: Date(), lastError: nil)]), navPath: .constant(NavigationPath()))
        }
    }
    .background(.listBackground)
}
