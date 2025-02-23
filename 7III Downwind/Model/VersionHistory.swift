//
//  VersionHistory.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.02.2025.
//

import Foundation

let versionHistory: [Version] = [
    // MARK: Newest on Top + Keep the introduction short to not get truncated text.
    
    Version(versionNumber: "1.1",
            introduction: "Big update:",
            changes: [
                "Stats Overview: Now showing the number of sessions for all disciplines, including distance and time.",
                "Stats Details: More speeds, turns, time on foil, and pop-ups for relevant sports.",
                "Stats Edit: You can now edit locations.",
                "Stats Filter: Added location and workout filters.",
                "Export: Added GPX export for Strava, race.downwind.app, and more.",
                "Note: Locations are now cached. This might take a while for large datasets, but you will not lose any data if you close and reopen the app."
            ],
            releaseDate: "February 2025"
           ),
    
    Version(versionNumber: "1.0.2",
            introduction: "More maintenance:",
            changes: [
                "Added Downwind Parawing to workout types.",
                "More bug fixes."
            ],
            releaseDate: "December 2024"
           ),
    
    Version(versionNumber: "1.0.1",
            introduction: "Maintenance:",
            changes: [
                "Added Parawing to workout types.",
                "Fixed some bugs related to tags."
            ],
            releaseDate: "November 2024"
           ),
    
    Version(
        versionNumber: "1.0",
        introduction: "Introducing 7III Water:",
        changes: [
            "Apple Watch and iPhone support.",
            "Capture and analyze your water sport performance.",
            "Health app integration.",
            "Privacy first."
        ],
        releaseDate: "September 2024"
    )
]
