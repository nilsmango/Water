//
//  MapAngle.swift
//  7III Tracker
//
//  Created by Simon Lang on 09.11.2025.
//

import MapKit

struct MapAngle: Identifiable, Codable {
    let id: UUID = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let angle: String
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        self.angle = calculateAngle(from: coordinates)
    }
}
