//
//  MapAngle.swift
//  7III Tracker
//
//  Created by Simon Lang on 09.11.2025.
//

import MapKit

struct MapAngle: Identifiable, Codable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let angle: String
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.id = UUID()
        self.coordinates = coordinates
        self.angle = calculateAngle(from: coordinates)
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, coordinates, angle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        angle = try container.decode(String.self, forKey: .angle)
        
        let coordData = try container.decode([[String: Double]].self, forKey: .coordinates)
        coordinates = coordData.map { dict in
            CLLocationCoordinate2D(
                latitude: dict["latitude"] ?? 0,
                longitude: dict["longitude"] ?? 0
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(angle, forKey: .angle)
        
        let coordData = coordinates.map { coord in
            ["latitude": coord.latitude, "longitude": coord.longitude]
        }
        try container.encode(coordData, forKey: .coordinates)
    }
}
