//
//  NavDestination.swift
//  7III Tracker
//
//  Created by Simon Lang on 08.08.2025.
//

import Foundation

enum NavDestination: Hashable {
    case dashboards
    case dashboard(Dashboard)
    case statistics
    case maps
}
