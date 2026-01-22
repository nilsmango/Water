//
//  Spot.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2026.
//

import Foundation
import MapKit


struct Spot: Codable, Identifiable, Equatable {
    struct Location: Codable, Equatable {
        let lat: Double
        let lng: Double
        
        var coordinate: CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
    
    let id: String
    let name: String
    let country: String
    let state: String?
    let kind: Kind
    let distance: Double?
    var pending: Bool?
    let locations: [Location]
    var infos: [SpotInfo]
    let videos: [Video]?
    
    var primaryLocation: Location? {
        locations.first
    }
    
    var isDownwindRun: Bool {
        kind == .downwindRun || locations.count >= 2
    }
}

extension Spot {
    enum Kind: String, Codable, CaseIterable {
        case pumpFoilDock = "pump-foil-dock"
        case wakeThiefSpot = "wake-thief-spot"
        case waveWindSpot = "wave-wind-spot"
        case windSpot = "wind-spot"
        case waveSpot = "wave-spot"
        case rentalStation = "rental-station"
        case shop = "shop"
        case school = "school"
        case wakeBoat = "wake-boat"
        case downwindRun = "downwind-run"
        case paddleTour = "paddle-tour"
        
        var label: String {
            switch self {
            case .pumpFoilDock:
                return "Pump Foil Dock"
            case .wakeThiefSpot:
                return "Wake Thief Spot"
            case .waveWindSpot:
                return "Wave & Wind Spot"
            case .windSpot:
                return "Wind Spot"
            case .waveSpot:
                return "Wave Spot"
            case .rentalStation:
                return "Rental Station"
            case .shop:
                return "Shop"
            case .school:
                return "School"
            case .wakeBoat:
                return "Wake Boat"
            case .downwindRun:
                return "Downwind Run"
            case .paddleTour:
                return "Paddle Tour"
            }
        }
        
        var iconName: String {
            switch self {
            case .pumpFoilDock:
                return "figure.pool.swim"
            case .wakeThiefSpot:
                return "water.waves"
            case .waveWindSpot:
                return "wind"
            case .windSpot:
                return "wind.snow"
            case .waveSpot:
                return "wave.3.right"
            case .rentalStation:
                return "building.2"
            case .shop:
                return "storefront"
            case .school:
                return "book.closed"
            case .wakeBoat:
                return "sailboat"
            case .downwindRun:
                return "arrow.right"
            case .paddleTour:
                return "figure.rowing"
            }
        }
        
        var accentColor: String {
            switch self {
            case .pumpFoilDock, .school:
                return "blue"
            case .wakeThiefSpot, .wakeBoat:
                return "purple"
            case .waveWindSpot, .waveSpot:
                return "teal"
            case .windSpot:
                return "orange"
            case .downwindRun:
                return "red"
            case .paddleTour:
                return "green"
            default:
                return "gray"
            }
        }
    }
}

struct SpotInfo: Codable, Identifiable, Equatable {
    let id: String
    let spotId: String?
    let tag: String
    let text: String
    let date: String
    let userName: String
    let userUrl: String?
    let votes: Int?
}

struct Video: Codable, Identifiable, Equatable {
    let id: String
    let url: String
    let date: String
    let kind: VideoKind
    
    enum CodingKeys: String, CodingKey {
        case url, date, kind
        case id = "id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(String.self, forKey: .url)
        self.date = try container.decode(String.self, forKey: .date)
        self.kind = try container.decode(VideoKind.self, forKey: .kind)
        self.id = UUID().uuidString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(date, forKey: .date)
        try container.encode(kind, forKey: .kind)
    }
}

enum VideoKind: String, Codable {
    case youtube = "YouTube"
    case insta = "Insta"
    case video = "Video"
}
