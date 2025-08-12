//
//  Model.swift
//  WebTrackerTest
//
//  Created by Simon Lang on 28.07.2025.
//

import Foundation
import SwiftUI

// MARK: - Data Manager
class TrackedElementsManager: ObservableObject {
    
    // MARK: - Dashboards
    
    @Published var dashboards: [Dashboard] = []
    @Published var widgetDashboardIds: [UUID] = []
    @AppStorage("preferredWindUnit") var preferredWindUnit: UnitType = .knots
    @AppStorage("preferredTempUnit") var preferredTempUnit: UnitType = .celsius
    @AppStorage("showGroupedInfo") var showGroupInfo: Bool = true
    @AppStorage("PulledDown") var pulledDownList: Bool = false
    @AppStorage("showWidgetTap") var showWidgetTap: Bool = true
    
    private let webService = WebScrapingService()
    
    init() {
        loadDashboards()
    }
    
    func deleteDashboards(offsets: IndexSet) {
        let removedIDs = offsets.map { dashboards[$0].id }
        dashboards.remove(atOffsets: offsets)
        widgetDashboardIds.removeAll { removedIDs.contains($0) }
        saveDashboards()
    }
    
    func deleteDashboard(_ dashboard: Dashboard) {
        if let index = dashboards.firstIndex(of: dashboard) {
            deleteDashboards(offsets: [index])
        }
    }
    
    func moveDashboards(from source: IndexSet, to destination: Int) {
        for index in source {
            dashboards.move(fromOffsets: [index], toOffset: destination)
        }
        saveDashboards()
    }
    
    func saveDashboards() {
        if let data = try? JSONEncoder().encode(dashboards) {
            UserDefaults.standard.set(data, forKey: "Dashboards")
        }
        if let data = try? JSONEncoder().encode(widgetDashboardIds) {
            UserDefaults.standard.set(data, forKey: "WidgetDashboards")
        }
    }
    
    private func loadDashboards() {
        if let data = UserDefaults.standard.data(forKey: "Dashboards"),
           let decoded = try? JSONDecoder().decode([Dashboard].self, from: data) {
            dashboards = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "WidgetDashboards"),
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            widgetDashboardIds = decoded
        }
    }
    
    // MARK: - Elements
    
    func addElement(_ element: TrackedElement, dashboardIndex: Int) {
        dashboards[dashboardIndex].elements.append(element)
        saveDashboards()
    }
    
    func editElement(_ element: TrackedElement, dashboardIndex: Int) {
        if let elementIndex = dashboards[dashboardIndex].elements.firstIndex(where: { $0.id == element.id }) {
            dashboards[dashboardIndex].elements[elementIndex] = element
            saveDashboards()
        }
    }
    
    func removeElement(_ element: TrackedElement, dashboardIndex: Int) {
        dashboards[dashboardIndex].elements.removeAll { $0.id == element.id }
        saveDashboards()
    }
    
    func clearAllElements(dashboardIndex: Int) {
        dashboards[dashboardIndex].elements.removeAll()
        saveDashboards()
    }
    
    func moveElements(from source: IndexSet, to destination: Int, elements: [TrackedElement], dashboardIndex: Int) {
        for index in source {
            let indexDifferential = destination - index
            if let globalIndex = dashboards[dashboardIndex].elements.firstIndex(where: { $0.id == elements[index].id }) {
                dashboards[dashboardIndex].elements.move(fromOffsets: [globalIndex], toOffset: globalIndex + indexDifferential)
            }
        }
        saveDashboards()
    }
    
    func moveGroupedElements(from source: IndexSet, to destination: Int, nestedElements: [[TrackedElement]], dashboardIndex: Int) {
        var nestedElements = nestedElements
        nestedElements.move(fromOffsets: source, toOffset: destination)
        dashboards[dashboardIndex].elements = nestedElements.flatMap { $0 }
        saveDashboards()
    }
    
    func deleteElements(from group: [TrackedElement], at indexSet: IndexSet, dashboardIndex: Int) {
        let elementsToRemove = indexSet.map { group[$0] }
        for element in elementsToRemove {
            if let globalIndex = dashboards[dashboardIndex].elements.firstIndex(where: { $0.id == element.id }) {
                dashboards[dashboardIndex].elements.remove(at: globalIndex)
            }
        }
        saveDashboards()
    }
    
    func makeNestedElements(dashboardIndex: Int) -> [[TrackedElement]] {
        let elements = dashboards[dashboardIndex].elements
        
        return makeNestedElements(from: elements)
    }
    
    func makeNestedElements(from elements: [TrackedElement]) -> [[TrackedElement]] {
        var nestedElements: [[TrackedElement]] = []
        
        for element in elements {
            var foundArray = false
            for (index, elementArray) in nestedElements.enumerated() {
                if elementArray.first!.url == element.url {
                    let commonPrefix = elementArray.first!.userLabel.commonPrefix(with: element.userLabel)
                    if commonPrefix.count >= 2 {
                        nestedElements[index].append(element)
                        foundArray = true
                        break
                    }
                }
            }
            if !foundArray {
                nestedElements.append([element])
            }
        }
        return nestedElements
    }
    
    func makeNestedElementsRow(elements: [TrackedElement]) -> (label: String?, url: String?, error: String?, rowText: [String], directionDegrees: Double?) {
        if elements.count == 1 {
            let displayValue = elements[0].displayValue(preferredWindUnit: preferredWindUnit, preferredTemperatureUnit: preferredTempUnit)
            return (label: elements[0].userLabel, url: elements[0].url, error: elements[0].lastError, rowText: [displayValue ?? ""], directionDegrees: degreesForDirection(displayValue ?? ""))
        } else {
            var label: String?
            var url: String?
            var error: String?
            var rowText = [String]()
            var directionDegrees: Double?
            
            for element in elements {
                if label == nil {
                    label = element.userLabel
                } else {
                    let commonPrefix = label!
                        .commonPrefix(with: element.userLabel)
                    label = String(commonPrefix).trimmingCharacters(in: .whitespaces)
                }
                
                if url == nil {
                    url = element.url
                }
                
                if error == nil {
                    error = element.lastError
                }
                if let displayValue = element.displayValue(preferredWindUnit: preferredWindUnit, preferredTemperatureUnit: preferredTempUnit) {
                    rowText.append(displayValue)
                    
                    if let degrees = degreesForDirection(displayValue) {
                        directionDegrees = degrees
                    }
                }
                
            }
            
            return (label: label, url: url, error: error, rowText: rowText, directionDegrees: directionDegrees)
        }
    }
    
    func degreesForDirection(_ value: String) -> Double? {
        let directionAngles: [String: Double] = [
            "N": 0, "NNO": 22.5, "NO": 45, "ONO": 67.5,  // German
            "O": 90, "OSO": 112.5, "SO": 135, "SSO": 157.5,  // German
            "S": 180, "SSW": 202.5, "SW": 225, "WSW": 247.5,
            "W": 270, "WNW": 292.5, "NW": 315, "NNW": 337.5,
            // English aliases
            "NNE": 22.5, "NE": 45, "ENE": 67.5,
            "E": 90, "ESE": 112.5, "SE": 135, "SSE": 157.5
        ]
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Check if it's a direction string first
        if let base = directionAngles[trimmed] {
            return (base + 180).truncatingRemainder(dividingBy: 360)
        }
        
        // Try to parse as numeric degrees
        var numericString = trimmed
        
        // Remove "DEGREES", "DEGREE", "DEG", or "°" suffix if present
        let degreesSuffixes = ["DEGREES", "DEGREE", "DEG", "°"]
        for suffix in degreesSuffixes {
            if numericString.hasSuffix(suffix) {
                numericString = String(numericString.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Try to convert to Double
        if let degrees = Double(numericString) {
            // Validate range 0-360
            if degrees >= 0 && degrees <= 360 {
                return (degrees + 180).truncatingRemainder(dividingBy: 360)
            }
        }
        
        return nil
    }
    
    @Published var expandedElements: [Set<UUID>] = []
    
    // MARK: - refreshing
    
    @AppStorage("maxWaitTime") var maxWaitTime: Double = 5.0
    @AppStorage("maxWaitAfter") var maxWaitAfterPlaceholder: Double = 2.0
    
    func refreshElement(_ element: TrackedElement, dashboardIndex: Int) async {
        let elements = dashboards[dashboardIndex].elements
        
        do {
            let value = try await webService.fetchElementValue(
                url: element.url,
                xpath: element.xpath,
                maxWaitTime: maxWaitTime,
                maxWaitAfterPlaceholder: maxWaitAfterPlaceholder
            )
            
            await MainActor.run {
                if let index = elements.firstIndex(where: { $0.id == element.id }) {
                    dashboards[dashboardIndex].elements[index].lastValue = value
                    dashboards[dashboardIndex].elements[index].lastUpdated = Date()
                    dashboards[dashboardIndex].elements[index].lastError = nil
                    saveDashboards()
                }
            }
        } catch {
            await MainActor.run {
                if let index = elements.firstIndex(where: { $0.id == element.id }) {
                    dashboards[dashboardIndex].elements[index].lastError = error.localizedDescription
                    dashboards[dashboardIndex].elements[index].lastUpdated = Date()
                    saveDashboards()
                }
            }
            print("Failed to refresh element \(element.userLabel): \(error)")
        }
    }
    
    @Published var refreshmentStatus: String?
    @Published var widgetRefreshmentStatus: String?
    private var completedCount = 0
    private var shouldCancelRefresh = false
        
    func cancelRefresh() {
        shouldCancelRefresh = true
    }
    
    func refreshDashboard(dashboard: Dashboard) async {
        if let index = dashboards.firstIndex(where: { $0.id == dashboard.id }) {
            await refreshAllElements(dashboardIndex: index)
        }
    }
    
    func refreshAllElements(dashboardIndex: Int) async {
        shouldCancelRefresh = false
        let dashboardToUpdate = dashboards[dashboardIndex]
        let elements = dashboardToUpdate.elements
        let total = elements.count
        
        await MainActor.run {
            completedCount = 0
            refreshmentStatus = "Refreshing | 0/\(total)"
            widgetRefreshmentStatus = "Refreshing \(dashboardToUpdate.name) | 0/\(total)"
        }
        
        let groupedByURL = Dictionary(grouping: elements) { $0.url }
        
        // Process each URL group
        for (url, elementsForURL) in groupedByURL {
            if shouldCancelRefresh {
                await MainActor.run {
                    refreshmentStatus = nil
                    widgetRefreshmentStatus = nil
                }
                return
            }
            let updatedGroup = await webService.processElementsForURL(url: url, elements: elementsForURL, maxWaitTime: maxWaitTime, maxWaitAfterPlaceholder: maxWaitAfterPlaceholder)
            await MainActor.run {
                if shouldCancelRefresh {
                    refreshmentStatus = nil
                    widgetRefreshmentStatus = nil
                    return
                }
                for element in updatedGroup {
                    if let index = dashboards[dashboardIndex].elements.firstIndex(where: { $0.id == element.id }) {
                        withAnimation {
                            dashboards[dashboardIndex].elements[index] = element
                        }
                        completedCount += 1
                        self.refreshmentStatus = "Refreshing | \(completedCount)/\(total)"
                        self.widgetRefreshmentStatus = "Refreshing \(dashboardToUpdate.name) | \(completedCount)/\(total)"
                    }
                }
            }
        }
        
        await MainActor.run {
            self.saveDashboards()
            refreshmentStatus = nil
            widgetRefreshmentStatus = nil
        }
    }
    
    // MARK: - Export/Import
    
    func exportDashboardJSON(dashboard: Dashboard) -> String? {
        do {
            let jsonData = try JSONEncoder().encode(dashboard)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    func importDashboardJSON(_ jsonString: String) -> Bool {
        guard let jsonData = jsonString.data(using: .utf8),
              let importedDashboard = try? JSONDecoder().decode(Dashboard.self, from: jsonData)
        else { return false }

        dashboards.append(importedDashboard)
        saveDashboards()
        
        return true
    }
    
    // MARK: - Main View Widgets
    
    func toggleWidgetEnabled(dashboardId: UUID) {
        if widgetDashboardIds.contains(dashboardId) {
            widgetDashboardIds.removeAll { $0 == dashboardId }
        } else {
            widgetDashboardIds.append(dashboardId)
        }
    }
    
    func canMoveWidgetUp(dashboardId: UUID) -> Bool {
        if let index = widgetDashboardIds.firstIndex(of: dashboardId) {
            return index > 0
        }
        return false
    }
    
    func canMoveWidgetDown(dashboardId: UUID) -> Bool {
        if let index = widgetDashboardIds.firstIndex(of: dashboardId) {
            return index < widgetDashboardIds.count - 1
        }
        return false
    }
    
    func moveWidgetUp(dashboardId: UUID) {
        if let index = widgetDashboardIds.firstIndex(of: dashboardId) {
            if index > 0 {
                widgetDashboardIds.swapAt(index, index - 1)
            }
        }
    }
    
    func moveWidgetDown(dashboardId: UUID) {
        if let index = widgetDashboardIds.firstIndex(of: dashboardId) {
            if index < widgetDashboardIds.count - 1 {
                widgetDashboardIds.swapAt(index, index + 1)
            }
        }
    }
}
