//
//  StallStatsOverlay.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.10.2025.
//

import SwiftUI

struct StallStatsOverlay: View {
    let events: [StallEvent]
    @State private var showCopiedAlert = false
    @Binding var isPresented: Bool
    
    var statsText: String {
        generateStatsText()
    }
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.0)
                            .ignoresSafeArea()
                            .allowsHitTesting(true)
                            .onTapGesture {
                                isPresented.toggle()
                            }
        
            VStack(spacing: 0) {
                // Header
                Text("Stall Analysis")
                    .font(.headline)
                .padding()
                .background(Color(uiColor: .systemBackground))
                
                // Stats text
                ScrollView {
                    Text(statsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .background(Color(uiColor: .systemBackground))
                
                // Copy button
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy to Clipboard")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.accent)
                    .foregroundColor(.white)
                }
                .background(Color(uiColor: .systemBackground))
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(25)
            .padding()
        
            // Copied alert
            if showCopiedAlert {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Copied!")
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(25)
                    .shadow(radius: 10)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = statsText
        
        withAnimation {
            showCopiedAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }
    
    private func generateStatsText() -> String {
        guard !events.isEmpty else {
            return "No stall events detected"
        }
        
        var text = ""
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        // Last stall speed
        if let lastStall = events.last {
            text += "Last Stall Speed: \(formatSpeed(lastStall.stallSpeed))\n\n"
        }
        
        // Header
        text += "Foil Stall Events Detected: \(events.count)\n\n"
        
        // Individual events
        for (i, event) in events.enumerated() {
            text += "Stall #\(i + 1)\n"
            text += "Time: \(formatter.string(from: event.timestamp))\n"
            text += "Stall Speed: \(formatSpeed(event.stallSpeed))\n"
            text += "Dropped to: \(formatSpeed(event.dropToSpeed))\n"
            text += "Speed Drop: \(String(format: "%.2f", event.speedDrop)) m/s\n"
            if i < events.count - 1 {
                text += "\n"
            }
        }
        
        // Average
        let avgStallSpeed = events.map { $0.stallSpeed }.reduce(0, +) / Double(events.count)
        text += "\nAverage Stall Speed: \(formatSpeed(avgStallSpeed))"
        
        return text
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        let ms = String(format: "%.2f", speed)
        let kmh = String(format: "%.1f", speed * 3.6)
        return "\(ms) m/s (\(kmh) km/h)"
    }
}
