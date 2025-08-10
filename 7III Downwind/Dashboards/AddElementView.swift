//
//  AddElementView.swift
//  WebTracker
//
//  Created by Simon Lang on 28.07.2025.
//

import SwiftUI

struct AddElementView: View {
    let manager: TrackedElementsManager
    let dashboardIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @Binding var element: TrackedElement
    
    @State private var showingWebView = false
    @State private var isTestingSelector = false
    
    private var numberOfNumbers: Int {
        let value = element.lastValue ?? ""
        
        if element.trimmingSelection == .numbers {
            let pattern = "[0-9]+(?:\\.[0-9]+)?"
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
            let numbers = matches.compactMap {
                Double((value as NSString).substring(with: $0.range))
            }
            return numbers.count
        } else {
            let wordCount = value.components(separatedBy: .whitespaces).count
            return wordCount
        }
        
    }
    
    var body: some View {
            Form {
                Section {
                    TextField("Label (e.g., Ka'a Average Wind)", text: $element.userLabel)
                    TextField("Website URL", text: $element.url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text(("Element Details"))
                }
                
                Section {
                    Button(element.xpath.isEmpty ? "Choose Selection" : "Change Selection") {
                        if !element.url.lowercased().hasPrefix("http://") && !element.url.lowercased().hasPrefix("https://") {
                            element.url = "https://" + element.url
                        }
                        showingWebView = true
                    }
                    .disabled(element.url.isEmpty)
                    
                    Text(element.xpath.isEmpty ? "❌ No Selection" : " ✅ Selection Active")
                    Text("XPath: \(element.xpath)")
                }
                
                Section {
                    Button {
                        testSelector()
                } label: {
                        HStack {
                            if isTestingSelector {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Testing...")
                            } else {
                                Text("Test & Edit Selection")
                            }
                        }
                    }
                    .disabled(element.url.isEmpty || element.xpath.isEmpty || isTestingSelector)
                    if let testResult = element.lastValue, !testResult.isEmpty {
                        TextField("Test Result", text: .constant(testResult))
                    }
                    
                }
                
                if element.lastValue != nil && !element.lastValue!.isEmpty && !element.lastValue!.hasPrefix("❌ Error:") {
                    Section {
                        Toggle("Trim to one Number or Word", isOn: $element.trimToOne)
                            .tint(.accentColor)
                        if element.trimToOne {
                            Picker("Kind:", selection: $element.trimmingSelection) {
                                ForEach(TrimSelection.allCases, id: \.self) { trim in
                                    Text(trim.rawValue.capitalized).tag(trim)
                                }
                            }
                            .pickerStyle(.segmented)
                            let range = numberOfNumbers>0 ? 0...numberOfNumbers-1 : 0...0
                            Stepper("Keep \(element.trimmingSelection == .numbers ? "Number" : "Word"): \(element.keepNumberNumber + 1)", value: $element.keepNumberNumber, in: range)
                        } else {
                            TextField("Pattern to remove from Start", text: $element.trimStart)
                            TextField("Patter to remove from End", text: $element.trimEnd)
                        }
                        TextField("Text to add at Start", text: $element.appendStart)
                        TextField("Text to append to End", text: $element.appendEnd)
                        
                        Picker("Unit", selection: $element.unitType) {
                            ForEach(UnitType.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!element.isNumber)
                        
                    } header: {
                        Text("Modify Output")
                    } footer: {
                        Text("Capitalization will be ignored for removing of patterns. If the output is a number (after trimming), you can add a unit to enable automatic conversion to your preferred unit as set in Settings. Degrees and directions will be displayed with an arrow.")
                    }
                    Section("Result") {
                        Text(element.displayValue(preferredWindUnit: manager.preferredWindUnit, preferredTemperatureUnit: manager.preferredTempUnit) ?? "")
                    }
                }
            
        }
        .sheet(isPresented: $showingWebView) {
            WebPreviewView(url: element.url, cssSelector: $element.xpath)
        }
    }
    
    private func testSelector() {
        
        isTestingSelector = true
        
        Task {
            do {
                let webService = WebScrapingService()
                
                let value = try await webService.fetchElementValue(url: element.url, xpath: element.xpath, maxWaitTime: manager.maxWaitTime, maxWaitAfterPlaceholder: manager.maxWaitAfterPlaceholder)
                
                await MainActor.run {
                    element.lastValue = value
                    element.lastUpdated = Date()
                    isTestingSelector = false
                }
            } catch {
                await MainActor.run {
                    element.lastValue = "❌ Error: \(error.localizedDescription)"
                    isTestingSelector = false
                }
            }
        }
    }
}


//#Preview {
//    AddElementView(manager: <#TrackedElementsManager#>, dashboardIndex: <#Int#>)
//}
