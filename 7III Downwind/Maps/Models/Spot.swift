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
    let usState: String?
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
                return "table.furniture.fill"
            case .wakeThiefSpot:
                return "ferry.fill"
            case .waveWindSpot:
                // TODO: make
                return "wind"
            case .windSpot:
                return "wind"
            case .waveSpot:
                return "water.waves"
            case .rentalStation:
                return "building.2"
            case .shop:
                return "storefront"
            case .school:
                return "graduationcap.fill"
            case .wakeBoat:
                return "ferry"
            case .downwindRun:
                return "point.topleft.down.to.point.bottomright.curvepath.fill"
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
    var tag: InfoTag
    var text: String
    let date: String
    var userName: String
    var userUrl: String?
    let votes: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.spotId = try container.decodeIfPresent(String.self, forKey: .spotId)
        
        if let tagValue = try? container.decode(InfoTag.self, forKey: .tag) {
            self.tag = tagValue
        } else if let tagString = try? container.decode(String.self, forKey: .tag),
                  let tagValue = InfoTag(rawValue: tagString) {
            self.tag = tagValue
        } else {
            self.tag = .description
        }
        
        self.text = try container.decode(String.self, forKey: .text)
        self.date = try container.decode(String.self, forKey: .date)
        self.userName = try container.decode(String.self, forKey: .userName)
        self.userUrl = try container.decodeIfPresent(String.self, forKey: .userUrl)
        self.votes = try container.decodeIfPresent(Int.self, forKey: .votes)
    }
    
    init(id: String, spotId: String? = nil, tag: InfoTag, text: String, date: String, userName: String, userUrl: String? = nil, votes: Int? = nil) {
        self.id = id
        self.spotId = spotId
        self.tag = tag
        self.text = text
        self.date = date
        self.userName = userName
        self.userUrl = userUrl
        self.votes = votes
    }
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
    
    init(id: String, url: String, date: String, kind: VideoKind? = nil) {
        self.id = id
        self.url = url
        self.date = date
        self.kind = kind ?? VideoKind.from(url: url)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(date, forKey: .date)
        try container.encode(kind, forKey: .kind)
    }
    
    func encodeForAPI() throws -> String {
        return url
    }
}

enum VideoKind: String, Codable {
    case youtube = "YouTube"
    case insta = "Insta"
    case video = "Video"
    case other = "Other"
    
    static func from(url: String) -> VideoKind {
        let lowercased = url.lowercased()
        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return .youtube
        } else if lowercased.contains("instagram.com") || lowercased.contains("instagr.am") {
            return .insta
        } else if lowercased.hasSuffix(".mp4") || lowercased.hasSuffix(".mov") || lowercased.hasSuffix(".avi") || lowercased.hasSuffix(".webm") {
            return .video
        }
        return .other
    }
}

enum InfoTag: String, Codable, CaseIterable {
    case description = "description"
    case windDirection = "wind-direction"
    case windMeasurements = "wind-measurements"
    case windPredictions = "wind-predictions"
    case conditions = "conditions"
    case logistics = "logistics"
    case localContact = "local-contact"
    case localRules = "local-rules"
    
    var displayName: String {
        switch self {
        case .description: return "Description"
        case .windDirection: return "Wind Direction"
        case .windMeasurements: return "Wind Measurements"
        case .windPredictions: return "Wind Predictions"
        case .conditions: return "Conditions"
        case .logistics: return "Logistics"
        case .localContact: return "Local Legends & Groups"
        case .localRules: return "Local Rules"
        }
    }
}
