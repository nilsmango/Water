//
//  NestedElementsRow.swift
//  WebTracker
//
//  Created by Simon Lang on 03.08.2025.
//

import SwiftUI

struct NestedElementsRow: View {
    let label: String?
    let url: String?
    let error: String?
    let rowText: [String]
    let directionDegrees: Double?
    let element: TrackedElement?
    let dashboardIndex: Int?
    let manager: TrackedElementsManager
    var animateDirectionArrow: Bool = true
    var showsNoDataForErrors: Bool = false
    var onExpand: () -> Void
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    
    @State private var animationDegrees: Double = 0

    private var displayedDirectionDegrees: Double {
        if !animateDirectionArrow {
            return directionDegrees ?? 0
        }
        return animationDegrees
    }
    
    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0.0)
            
            if !rowText.isEmpty {
                if error != nil, showsNoDataForErrors {
                    Text("- No Data Found -")
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if error != nil {
//                    HStack {
//                        Image(systemName: "exclamationmark.triangle")
                        
                    Text(error!)
//                    }
                    .lineLimit(1)
                    .foregroundColor(.orange)
                } else {
                    HStack {
                        ForEach(Array(rowText.enumerated()), id: \.0) { index, text in
                            if index > 0 {
                                Text(" | ")
                            }
                            if text.isEmpty {
                                if error != nil {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                } else {
                                    Text("-")
                                }
                                
                            } else {
                                Text(text)
                                    .scaleEffect(1.0)
                            }
                        }
                        
                        if directionDegrees != nil {
                            let size = 16.0
                            Image(systemName: "arrow.up")
                                .rotationEffect(.degrees(displayedDirectionDegrees))
                                .frame(width: size, height: size)
                        }
                    }
                }
                
            } else {
                Text("--")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if animateDirectionArrow, let directionDegrees = directionDegrees {
                withAnimation {
                    animationDegrees = directionDegrees
                }
            }
        }
        .onChange(of: directionDegrees) {
            if animateDirectionArrow, let directionDegrees = directionDegrees {
                withAnimation {
                    animationDegrees = directionDegrees
                }
            }
        }
        .listRowSeparator(.hidden)
        .ifLet(dashboardIndex) { view, dashboardIndex in
            view.contextMenu {
                if let url = url {
                    Link(destination: URL(string: url)!) {
                        Label("Go to Source", systemImage: "globe")
                    }
                }
                if element == nil {
                    Button {
                        onExpand()
                    } label: {
                        Label("Expand", systemImage: "chevron.down")
                    }
                } else {
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
                        manager.removeElement(element!, dashboardIndex: dashboardIndex)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                
            }
        }
        
    }
}



#Preview {
    List {
        NestedElementsRow(label: "Vinguelz", url: "https://example.com", error: "some error because not found", rowText: ["4.5 kn", "", "SW"], directionDegrees: 45.0, element: nil, dashboardIndex: nil, manager: TrackedElementsManager(), onExpand: {}, onEdit: {}, onDuplicate: {})
            .listRowSeparator(.hidden)
        NestedElementsRow(label: "Vinguelz", url: "https://example.com", error: "some error", rowText: ["4.5 kn", "", "SW"], directionDegrees: 45.0, element: nil, dashboardIndex: nil, manager: TrackedElementsManager(), onExpand: {}, onEdit: {}, onDuplicate: {})
            .listRowSeparator(.hidden)
    }
    
    
}
