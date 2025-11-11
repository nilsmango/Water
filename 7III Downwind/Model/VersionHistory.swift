//
//  VersionHistory.swift
//  7III Tracker
//
//  Created by Simon Lang on 23.02.2025.
//

import Foundation

let versionHistory: [Version] = [
    // MARK: Newest on Top + Keep the introduction short to not get truncated text.
    Version(versionNumber: "1.3",
            introduction: "Dashboards!",
            changes: [
                "Added Dashboards for pulling multiple wind stations’ data into one place.",
                "Dashboards can get pinned to the Main View.",
                "A cleaner Main View with more control over what you see.",
                "Better GPS smoothing for non-downwind Maps.",
                "Indicating waves in maps now for some water sports.",
                "Added Error Logging for GPS Tracking with iPhone.",
                "Various bug fixes.",
                "Updated design for iOS 26.",
                "Added Speed Chart, Angle Tool, and Foil Stall Analysis to Stats."
            ],
            releaseDate: "November 2025"
           ),
    
    Version(versionNumber: "1.2",
            introduction: "Improvements:",
            changes: [
                "Better route edit map.",
                "Fixed Apple Watch using Digital Crown bugs.",
                "Improved 1 and 10 second Top Speed finding.",
                "You can now set Foiling Threshold speeds in Options.",
                "Added version number in Help and Options.",
                "Selected Tags now persist between sessions on Apple Watch.",
                "Added new Activities: PW Skate, E-Foil, E-Assist.",
                "Added full screen Map Photo export option.",
                "Added statistics Sticker Overlay export option.",
                "Unlocked 4 free Route Edits and unlimited Tags in free version."
            ],
            releaseDate: "July 2025"
           ),
    
    Version(versionNumber: "1.1",
            introduction: "Big update:",
            changes: [
                "Stats Overview: Now showing the number of sessions for all disciplines, including distance and time.",
                "Stats Details: More speeds, turns, time on foil, max distance on foil, and pop-ups for relevant sports.",
                "Stats Edit: You can now edit locations.",
                "Stats Filter: Added location and workout filters.",
                "Export: Added GPX export for Strava, race.downwind.app, and more.",
                "Apple Watch: Added option to restrict starting and stoping of sessions to turning the Digital Crown. Water lock now gets activated automatically.",
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
                "Fixed some bugs related to Tags."
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
