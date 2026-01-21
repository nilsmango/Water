//
//  MapDebug.swift
//  7III Downwind
//
//  Created by Simon Lang on 19.01.2026.
//

import Foundation

var isMapDebugEnabled: Bool = false

func debugMap(_ message: String) {
    guard isMapDebugEnabled else { return }
    #if DEBUG
    print("🗺️ MapDebug:", message)
    #endif
}

