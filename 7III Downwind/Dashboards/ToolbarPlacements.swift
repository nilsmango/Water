//
//  ToolbarPlacements.swift
//  7III Tracker
//
//  Created by Simon Lang on 13.08.2025.
//

import SwiftUI

var toolbarTrailingPlacement: ToolbarItemPlacement {
    #if os(iOS)
    return .navigationBarTrailing
    #else
    return .primaryAction
    #endif
}

var toolbarLeadingPlacement: ToolbarItemPlacement {
    #if os(iOS)
    return .navigationBarLeading
    #else
    return .cancellationAction
    #endif
}

