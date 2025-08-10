//
//  ContentView.swift
//  WebTrackerTest
//
//  Created by Simon Lang on 28.07.2025.
//
import SwiftUI

struct Dashboards: View {
    @ObservedObject var manager: TrackedElementsManager
    
    @State private var showingAddAlert = false
    @State private var isEdit = false
    @State private var showingInfoAlert = false
    @State private var newDashboardName = ""
    @State private var newDashboardId: UUID?
    @State private var isImportingDashboard = false
    @State private var isLoadingImportedDashboards = false
    @Binding var navPath: NavigationPath
    
    var body: some View {
        List {
            
            if isLoadingImportedDashboards {
                Section {
                    
                } header: {
                    Text("Importing new Dashboards...")
                }
            }
            
            ForEach(manager.dashboards) { dashboard in
                NavigationLink(value: dashboard) {
                    let isWidgetEnabled = manager.widgetDashboardIds.contains(dashboard.id)
                    DashboardRow(name: dashboard.name, isWidgetEnabled: isWidgetEnabled)
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
                                manager.toggleWidgetEnabled(dashboardId: dashboard.id)
                            } label: {
                                Label(isWidgetEnabled ? "Remove from Main View" : "Add to Main View", systemImage: isWidgetEnabled ? "pin.slash.fill" : "pin.fill")
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
                Menu {
                    Button {
                        showingAddAlert = true
                    } label: {
                        Label("New", systemImage: "sparkles")
                    }
                    
                    Button {
                        isImportingDashboard = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    
                } label: {
                    Label("Add Dashboard", systemImage: "plus.circle.fill")
                }
                
            }
        }
        .fileImporter(
            isPresented: $isImportingDashboard,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true
        ) { result in
            isLoadingImportedDashboards = true

                switch result {
                case .success(let urls):
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            if let jsonString = try? String(contentsOf: url) {
                                let itWorked = manager.importDashboardJSON(jsonString)
                                print("Imported \(url.lastPathComponent): \(itWorked)")
                            } else {
                                print("Failed to read file: \(url.lastPathComponent)")
                            }
                        } else {
                            print("Could not access file: \(url.lastPathComponent)")
                        }
                    }
                    isLoadingImportedDashboards = false

                case .failure(let error):
                    print("Error importing files: \(error)")
                    isLoadingImportedDashboards = false
                    
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
    Dashboards(manager: TrackedElementsManager(), navPath: .constant(NavigationPath()))
}


