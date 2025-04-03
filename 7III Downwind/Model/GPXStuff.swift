//
//  GPXStuff.swift
//  7III Tracker
//
//  Created by Simon Lang on 02.04.2025.
//

import Foundation

struct GPX: Codable {
    let trk: [Track]
}

struct Track: Codable {
    let name: String
    let type: String
    let trkseg: [TrackSegment]
}

struct TrackSegment: Codable {
    let trkpt: [TrackPoint]
}

struct TrackPoint: Codable {
    let lat: String
    let lon: String
    let ele: String?
    let time: Date?
    let speed: Double?
    let extensions: Extensions?
}

struct Extensions: Codable {
    let trackPointExtension: TrackPointExtension?

    enum CodingKeys: String, CodingKey {
        case trackPointExtension = "ns3:TrackPointExtension"
    }
}

struct TrackPointExtension: Codable {
    let hr: String?

    enum CodingKeys: String, CodingKey {
        case hr = "ns3:hr"
    }
}
