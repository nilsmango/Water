//
//  MapDebug.swift
//  7III Tracker
//
//  Created by Simon Lang on 19.01.2026.
//

import Foundation

func debugMap(_ message: String) {
    #if DEBUG
    print("🗺️ MapDebug:", message)
    #endif
}
