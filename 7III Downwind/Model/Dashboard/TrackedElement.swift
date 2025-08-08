//
//  TrackedElement.swift
//  WebTracker
//
//  Created by Simon Lang on 28.07.2025.
//

import Foundation

struct TrackedElement: Codable, Identifiable, Hashable {
    let id = UUID()
    var url: String
    var xpath: String
    var userLabel: String
    var lastValue: String?
    var lastUpdated: Date?
    var lastError: String?
    
    var trimStart: String = ""
    var trimEnd: String = ""
    var trimToOne: Bool = false
    var trimmingSelection: TrimSelection = .words
    var keepNumberNumber = 0
    var appendStart: String = ""
    var appendEnd: String = ""
    var unitType: UnitType = .none
    
    var isNumber: Bool {
        if trimToOne && trimmingSelection == .numbers {
            return true
        } else {
            guard var value = lastValue else { return false }

            if !trimStart.isEmpty, value.lowercased().hasPrefix(trimStart.lowercased()) {
                value.removeFirst(trimStart.count)
            }
            if !trimEnd.isEmpty, value.lowercased().hasSuffix(trimEnd.lowercased()) {
                value.removeLast(trimEnd.count)
            }
            
            if Double(value) != nil {
                return true
            } else {
                return false
            }
        }
    }

    func displayValue(preferredWindUnit: UnitType, preferredTemperatureUnit: UnitType) -> String? {
        guard var value = lastValue else { return nil }
        
        if !trimToOne {
            if !trimStart.isEmpty, value.lowercased().hasPrefix(trimStart.lowercased()) {
                value.removeFirst(trimStart.count)
            }
            if !trimEnd.isEmpty, value.lowercased().hasSuffix(trimEnd.lowercased()) {
                value.removeLast(trimEnd.count)
            }
        } else {
            if trimmingSelection == .words {
                let words = value.components(separatedBy: .whitespaces)
                let trimmedWords = words.map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
                value = trimmedWords.indices.contains(keepNumberNumber) ? trimmedWords[keepNumberNumber] : ""
            } else {
                let pattern = "[0-9]+(?:\\.[0-9]+)?"
                let regex = try! NSRegularExpression(pattern: pattern)
                let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
                let numbers = matches.compactMap {
                    Double((value as NSString).substring(with: $0.range))
                }
                value = numbers.indices.contains(keepNumberNumber) ? String(numbers[keepNumberNumber]) : ""
            }
        }
        
        if unitType != .none {
            if unitType.isTemperature, preferredTemperatureUnit != .none, let original = Double(value) {
                if unitType != preferredTemperatureUnit {
                    let converted = UnitConverter.convert(original, from: unitType, to: preferredTemperatureUnit)
                    value = String(format: "%.1f", converted)
                }
                value +=  " " + preferredTemperatureUnit.rawValue
            } else if preferredWindUnit != .none,
                      let original = Double(value) {
                if unitType != preferredWindUnit {
                    let converted = UnitConverter.convert(original, from: unitType, to: preferredWindUnit)
                    value = String(format: "%.1f", converted)
                }
                value += " " + preferredWindUnit.rawValue
            }
        }

        return appendStart + value + appendEnd
    }
    
    enum CodingKeys: String, CodingKey {
        case url, xpath, userLabel, lastValue, lastUpdated, lastError, trimStart, trimEnd, appendStart, appendEnd, trimToOne, trimmingSelection, keepNumberNumber, unitType
    }
}

enum TrimSelection: String, CaseIterable, Codable {
    case words
    case numbers
}
