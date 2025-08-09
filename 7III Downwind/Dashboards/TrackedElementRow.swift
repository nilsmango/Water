//
//  TrackedElementRow.swift
//  WebTracker
//
//  Created by Simon Lang on 28.07.2025.
//

import SwiftUI

struct TrackedElementRow: View {
    let element: TrackedElement
    let manager: TrackedElementsManager
    let dashboardIndex: Int
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    
    var body: some View {
        HStack {
            Text(element.userLabel)
                .font(.headline)
            
            Spacer(minLength: 0.0)
            
            if let error = element.lastError {
                Text(error)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                
            } else if let value = element.displayValue(preferredWindUnit: manager.preferredWindUnit, preferredTemperatureUnit: manager.preferredTempUnit) {
                HStack {
                    Text(value)
                    
                    if let deg = manager.degreesForDirection(value) {
                        Image(systemName: "arrow.up")
                            .rotationEffect(.degrees(deg))
                    }
                }
            } else {
                Text("--")
                    .foregroundColor(.secondary)
            }
        }        
        .contextMenu {
            Link(destination: URL(string: element.url)!) {
                Label("Go to Source", systemImage: "globe")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "document.on.document")
            }
            Button(role: .destructive) {
                manager.removeElement(element, dashboardIndex: dashboardIndex)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    TrackedElementRow(element: TrackedElement(url: "https://www.google.com", xpath: "body", userLabel: "Very long label"), manager: TrackedElementsManager(), dashboardIndex: 0, onEdit: {}, onDuplicate: {})
}
