//
//  ContentView.swift
//  WebTrackerTest
//
//  Created by Simon Lang on 28.07.2025.
//
import SwiftUI

struct Dashboards: View {
    @StateObject private var manager = TrackedElementsManager()
    @State private var showingAddAlert = false
    @State private var isEdit = false
    @State private var showingInfoAlert = false
    @State private var newDashboardName = ""
    @State private var newDashboardId: UUID?
    @Binding var navPath: NavigationPath
    
    var body: some View {
        List {
            ForEach(manager.dashboards) { dashboard in
                NavigationLink(value: dashboard) {
                    Text(dashboard.name)
                        .contextMenu {
                            Button {
                                newDashboardName = dashboard.name
                                newDashboardId = dashboard.id
                                isEdit = true
                                showingAddAlert = true
                            } label: {
                                Label("Edit Name", systemImage: "square.and.pencil")
                            }
                            
                            Button {
                                newDashboardName = dashboard.info ?? ""
                                newDashboardId = dashboard.id
                                showingInfoAlert = true
                            } label: {
                                Label("Edit Info", systemImage: "info.circle")
                            }
                            
                            Button {
                                if let jsonString = manager.exportDashboardJSON(dashboard: dashboard) {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(dashboard.name).json")
                                    try? jsonString.data(using: .utf8)?.write(to: tempURL)
                                    let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                                    
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        window.rootViewController?.present(activityVC, animated: true)
                                    }
                                }
                            } label: {
                                Label("Share \(dashboard.name)", systemImage: "square.and.arrow.up")
                            }
                        }
                }
            }
            .onDelete(perform: manager.deleteDashboards)
            .onMove(perform: manager.moveDashboards)
        }
        .navigationTitle("Dashboards")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Dashboard.self) { dashboard in
            if let index = manager.dashboards.firstIndex(where: { $0.id == dashboard.id }) {
                DashboardView(manager: manager, dashboardIndex: index)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddAlert = true
                } label: {
                    Label("Add Dashboard", systemImage: "plus.circle.fill")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DashboardSettingsView(manager: manager)
                } label: {
                    Label("Settings", systemImage: "ellipsis.circle.fill")
                }
                
            }
        }
        .alert(isEdit ? "Edit Name" : "Name your Dashboard", isPresented: $showingAddAlert, actions: {
            TextField("Name", text: $newDashboardName)
            Button(isEdit ? "Update" : "Create") {
                if isEdit {
                    if let index = manager.dashboards.firstIndex(where: { $0.id == newDashboardId }) {
                        manager.dashboards[index].name = newDashboardName
                        manager.saveDashboards()
                        isEdit = false
                    }
                } else {
                    let newDashboard = Dashboard(name: newDashboardName, elements: [])
                    manager.dashboards.append(newDashboard)
                    manager.saveDashboards()
                    navPath.append(newDashboard)
                    
                }
                newDashboardName = ""
                
            }
            Button("Cancel", role: .cancel) {
                newDashboardName = ""
                isEdit = false
            }
        })
        
        .alert("Edit Info", isPresented: $showingInfoAlert, actions: {
            TextField("Info", text: $newDashboardName)
            Button("Save") {
                if let index = manager.dashboards.firstIndex(where: { $0.id == newDashboardId }) {
                    manager.dashboards[index].info = newDashboardName
                    manager.saveDashboards()
                }
                
                newDashboardName = ""
                
            }
            Button("Cancel", role: .cancel) {
                newDashboardName = ""
            }
        })
    }
}

#Preview {
    Dashboards(navPath: .constant(NavigationPath()))
}


