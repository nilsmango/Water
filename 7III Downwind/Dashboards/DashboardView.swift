//
//  DashboardView.swift
//  WebTracker
//
//  Created by Simon Lang on 29.07.2025.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var manager: TrackedElementsManager
    @ObservedObject var downwindManager: DownwindManager
    
    let dashboardIndex: Int
    @Binding var navPath: NavigationPath
    
    @State private var showingAddSheet = false
    @State private var editingElement = false
    @State private var autoRefreshTimer: Timer?
    @State private var isAutoRefreshEnabled = false
    @State private var newElement = TrackedElement(url: "", xpath: "", userLabel: "")
    
    var body: some View {
        let name = manager.dashboards[dashboardIndex].name
        List {
            if manager.dashboards[dashboardIndex].elements.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "globe")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Elements Tracked")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Tap the ⋯ in the top right, then select 'Add New' to add your first web element to track")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
            } else {
                Section {
                    let nestedElements = manager.makeNestedElements(dashboardIndex: dashboardIndex)
                    ForEach(nestedElements, id: \.self) { elements in
                        #if os(macOS)
                        let isNotMac = false
                        #else
                        let isNotMac = true
                        #endif
                        let doNotShow = !downwindManager.hasPurchasedPremium && nestedElements.firstIndex(of: elements) != 0 && isNotMac
                        if doNotShow {
                            Button {
                                navPath = NavigationPath()
                                downwindManager.showUpgradeSheet = true
                                
                            } label: {
                                Label("Unlock unlimited Elements", systemImage: "lock.fill")
                            }
                            .listRowSeparator(.hidden)
                        } else {
                            let row = manager.makeNestedElementsRow(elements: elements)
                            let element: TrackedElement? = elements.count == 1 ? elements[0] : nil
                            if !manager.expandedElements.contains(Set(elements.map(\.id))) {
                                NestedElementsRow(label: row.label, url: row.url, error: row.error, rowText: row.rowText, directionDegrees: row.directionDegrees, element: element, dashboardIndex: dashboardIndex, manager: manager, onExpand: {
                                    manager.expandedElements.append(Set(elements.map(\.id)))
                                }, onEdit: {
                                    newElement = element!
                                    editingElement = true
                                    showingAddSheet = true
                                    
                                }, onDuplicate: {
                                    if let element = element {
                                        newElement = TrackedElement(url: element.url, xpath: element.xpath, userLabel: element.userLabel, lastValue: "", lastUpdated: nil, lastError: nil, trimStart: element.trimStart, trimEnd: element.trimEnd, trimToOne: element.trimToOne, trimmingSelection: element.trimmingSelection, keepNumberNumber: element.keepNumberNumber, appendStart: element.appendStart, appendEnd: element.appendEnd)
                                        showingAddSheet = true
                                    }
                                })
                            } else {
                                Button {
                                    if let index = manager.expandedElements.firstIndex(of: Set(elements.map(\.id))) {
                                        manager.expandedElements.remove(at: index)
                                    }
                                } label: {
                                    HStack {
                                        Text(row.label ?? "")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .foregroundColor(.primary)
                                
                                ForEach(elements) { element in
                                    TrackedElementRow(element: element, manager: manager, dashboardIndex: dashboardIndex, onEdit: {
                                        newElement = element
                                        editingElement = true
                                        showingAddSheet = true
                                    }, onDuplicate: {
                                        newElement = TrackedElement(url: element.url, xpath: element.xpath, userLabel: element.userLabel, lastValue: "", lastUpdated: nil, lastError: nil, trimStart: element.trimStart, trimEnd: element.trimEnd, trimToOne: element.trimToOne, trimmingSelection: element.trimmingSelection, keepNumberNumber: element.keepNumberNumber, appendStart: element.appendStart, appendEnd: element.appendEnd)
                                        showingAddSheet = true
                                    })
                                }
                                .onDelete { indexSet in
                                    manager.deleteElements(from: elements, at: indexSet, dashboardIndex: dashboardIndex)
                                }
                                .onMove { indexSet, index in
                                    manager.moveElements(from: indexSet, to: index, elements: elements, dashboardIndex: dashboardIndex)
                                }
                            }
                        }
                    }
                    .onMove { indexSet, index in
                        manager.moveGroupedElements(from: indexSet, to: index, nestedElements: nestedElements, dashboardIndex: dashboardIndex)
                        
                    }
                } header: {
                    if let status = manager.refreshmentStatus {
                        Text(status)
                            .monospacedDigit()
                    } else {
                        if let updated = manager.dashboards[dashboardIndex].elements.first?.lastUpdated {
                            Text("Last updated: \(Text(updated, style: .relative)) ago")
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        #if os(iOS)
                        if manager.pulledDownList == false {
                            Text("ℹ️ Pull down to refresh the list!")
                        }
                        #endif
                        if manager.showGroupInfo {
                            Text("💡 Elements with the same URL and a label sharing at least a 2-character prefix will be grouped.")
                        }
                        Text("🤙 Don't forget to support your local wind stations!")
                        
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .environment(\.defaultMinListRowHeight, 0)
        .navigationTitle(name)
        .refreshable {
            if manager.refreshmentStatus == nil {
                await manager.refreshAllElements(dashboardIndex: dashboardIndex)
                manager.pulledDownList = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: toolbarTrailingPlacement) {
                Menu {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add New", systemImage: "plus")
                    }
                    
                    Button(action: {
                        Task {
                            await manager.refreshAllElements(dashboardIndex: dashboardIndex)
                        }
                    }) {
                        Label("Refresh List", systemImage: "arrow.clockwise")
                    }
                    .disabled(manager.refreshmentStatus != nil)
                    
                    Button(action: toggleAutoRefresh) {
                        Label(
                            isAutoRefreshEnabled ? "Stop Auto Refresh" : "Start Auto Refresh (3 min)",
                            systemImage: isAutoRefreshEnabled ? "pause.circle" : "timer"
                        )
                    }
                    
                    let dashboardId = manager.dashboards[dashboardIndex].id
                    let isWidgetEnabled = manager.widgetDashboardIds.contains(dashboardId)
                    Button {
                        manager.toggleWidgetEnabled(dashboardId: dashboardId)
                    } label: {
                        Label(isWidgetEnabled ? "Remove from Main View" : "Add to Main View", systemImage: isWidgetEnabled ? "pin.slash.fill" : "pin.fill")
                    }
                    
                    Button {
                        let dashboard = manager.dashboards[dashboardIndex]
                        if let jsonString = manager.exportDashboardJSON(dashboard: dashboard) {
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(dashboard.name).json")
                            try? jsonString.data(using: .utf8)?.write(to: tempURL)
                            
                            #if os(macOS)
                            let sharingPicker = NSSharingServicePicker(items: [tempURL])
                            
                            // Get the current window
                            if let window = NSApp.keyWindow {
                                // Show the sharing picker at the button location
                                sharingPicker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
                            }
                            #else
                            // iOS fallback (your original code)
                            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                            
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController?.present(activityVC, animated: true)
                            }
                            #endif
                        }
                    } label: {
                        Label("Share \(name)", systemImage: "square.and.arrow.up")
                    }
                    
                    if let infoText = manager.dashboards[dashboardIndex].info, infoText != "" {
                        Label(infoText, systemImage: "info.circle")
                    }
                    
                    
                } label: {
                    if #available(iOS 26, *) {
                        Label("Options", systemImage: "ellipsis")

                    } else {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                    
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                AddElementView(manager: manager, dashboardIndex: dashboardIndex, element: $newElement)
                    .navigationTitle(editingElement ? "Edit Element" : "Add Element")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                    .toolbar {
                        ToolbarItem(placement: toolbarLeadingPlacement) {
                            Button("Cancel") {
                                showingAddSheet = false
                                editingElement = false
                                newElement = TrackedElement(url: "", xpath: "", userLabel: "")
                            }
                        }
                        ToolbarItem(placement: toolbarTrailingPlacement) {
                            Button(editingElement ? "Update" : "Save") {
                                if editingElement {
                                    manager.editElement(newElement, dashboardIndex: dashboardIndex)
                                } else {
                                    manager.addElement(newElement, dashboardIndex: dashboardIndex)
                                }
                                
                                showingAddSheet = false
                                editingElement = false
                                newElement = TrackedElement(url: "", xpath: "", userLabel: "")
                            }
                            .disabled(newElement.url.isEmpty || newElement.xpath.isEmpty || newElement.userLabel.isEmpty)
                        }
                    }
            }
            
        }
        .onAppear {
            if manager.refreshmentStatus == nil {
                if manager.dashboards[dashboardIndex].elements.first?.lastUpdated ?? Date() < Date().addingTimeInterval(-180) {
                    Task {
                        await manager.refreshAllElements(dashboardIndex: dashboardIndex)
                    }
                }
            }
        }
        .onDisappear {
            if manager.refreshmentStatus != nil {
                manager.cancelRefresh()
            }
            if isAutoRefreshEnabled {
                toggleAutoRefresh()
            }
        }
    }
    
    private func toggleAutoRefresh() {
        if isAutoRefreshEnabled {
            autoRefreshTimer?.invalidate()
            autoRefreshTimer = nil
            isAutoRefreshEnabled = false
        } else {
            if manager.refreshmentStatus == nil {
                Task {
                    await manager.refreshAllElements(dashboardIndex: dashboardIndex)
                }
            }
            autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { _ in
                if manager.refreshmentStatus == nil {
                    Task {
                        await manager.refreshAllElements(dashboardIndex: dashboardIndex)
                    }
                }
            }
            isAutoRefreshEnabled = true
        }
    }
}

//#Preview {
//    NavigationStack {
//        DashboardView(manager: TrackedElementsManager(), dashboardIndex: 0)
//    }
//}
