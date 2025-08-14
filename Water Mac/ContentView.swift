//
//  ContentView.swift
//  Water Mac
//
//  Created by Simon Lang on 13.08.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = TrackedElementsManager()
    @StateObject private var downwindManager = DownwindManager()
    @State private var navPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navPath) {
            Dashboards(manager: manager, downwindManager: downwindManager, navPath: $navPath)
                .onAppear {
                    Task {
                        await downwindManager.updateCustomerProductStatus()
                    }
                }
        }
        .navigationDestination(for: NavDestination.self) { destination in
            switch destination {
            case .dashboards:
                Dashboards(manager: manager, downwindManager: downwindManager, navPath: $navPath)
            case .dashboard(let dashboard):
                if let index = manager.dashboards.firstIndex(where: { $0.id == dashboard.id }) {
                    DashboardView(manager: manager, downwindManager: downwindManager, dashboardIndex: index, navPath: $navPath)
                }
            case .statistics:
                EmptyView()
            }
        }
        .navigationTitle("Aloha!")
    }
}

#Preview {
    ContentView()
}
