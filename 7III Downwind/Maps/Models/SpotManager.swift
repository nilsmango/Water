//
//  SpotManager.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2026.
//

import Foundation
import Combine
import SwiftUI



@MainActor
class SpotManager: ObservableObject {
    static let shared = SpotManager()
    
    private init() {}
    
    @AppStorage("spotsData") private var spotsData: Data = Data()
    @AppStorage("refreshInterval") private var refreshInterval: TimeInterval = 60 * 60
    
    private var spotsLastUpdated: Date? {
        get {
            UserDefaults.standard.object(forKey: "spotsLastUpdated") as? Date
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: "spotsLastUpdated")
            } else {
                UserDefaults.standard.removeObject(forKey: "spotsLastUpdated")
            }
        }
    }
    
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let spotsURL = URL(string: "https://project7iii.com/foildata/map/spots.json")!
    
    func loadSpots() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadFromCacheAsync()
            }
            group.addTask {
                await self.fetchSpotsFromServer()
            }
        }
    }
    
    private func loadFromCacheAsync() async {
        guard !spotsData.isEmpty else { return }
        
        let data = spotsData
        
        let spots = await Task.detached {
            guard let decodedSpots = try? JSONDecoder().decode([Spot].self, from: data) else {
                return [Spot]()
            }
            return decodedSpots
        }.value
        
        if !spots.isEmpty {
            self.spots = spots
        }
    }
    
    func refreshSpots() async {
        await fetchSpotsFromServer()
    }
    
    private func fetchSpotsFromServer() async {
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: spotsURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SpotError.badResponse
            }
            
            let decoder = JSONDecoder()
            let fetchedSpots = try decoder.decode([Spot].self, from: data)
            
            self.spots = fetchedSpots
            saveToCache(fetchedSpots)
            spotsLastUpdated = Date()
            
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to fetch spots: \(error)")
        }
        
        isLoading = false
    }
    
    private func saveToCache(_ spots: [Spot]) {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(spots)
            spotsData = encodedData
        } catch {
            print("Failed to encode spots: \(error)")
        }
    }
    
    private func shouldRefresh() -> Bool {
        guard let lastUpdated = spotsLastUpdated else {
            return true
        }
        
        return Date().timeIntervalSince(lastUpdated) > refreshInterval
    }
    
    func filteredSpots(kinds: Set<Spot.Kind>) -> [Spot] {
        if kinds.isEmpty {
            return []
        }
        
        return spots.filter { kinds.contains($0.kind) }
    }
    
    func validateSpot(_ request: SubmitSpotRequest) throws {
        guard !request.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.nameRequired
        }
        
        guard !request.country.isEmpty else {
            throw ValidationError.countryRequired
        }
        
        guard !request.kind.isEmpty else {
            throw ValidationError.kindRequired
        }
        
        guard !request.locations.isEmpty else {
            throw ValidationError.locationsRequired
        }
        
        for loc in request.locations {
            guard let lat = loc["lat"], let lng = loc["lng"] else {
                throw ValidationError.invalidLocation
            }
            guard lat >= -90 && lat <= 90 else {
                throw ValidationError.invalidLatitude
            }
            guard lng >= -180 && lng <= 180 else {
                throw ValidationError.invalidLongitude
            }
        }
        
        guard request.locations.count == 1 || !request.locations.filter({ $0["lat"] != nil && $0["lng"] != nil }).isEmpty else {
            throw ValidationError.invalidLocationsFormat
        }
        
        if request.kind == "downwind-run" || request.kind == "paddle-tour" {
            guard request.distance != nil && request.distance! > 0 else {
                throw ValidationError.distanceRequired
            }
        }
        
        if request.country == "US" && request.usState == nil {
            throw ValidationError.stateRequiredForUS
        }
        
        for info in request.infos {
            guard !info.text.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.infoTextRequired
            }
            guard !info.userName.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.userNameRequired
            }
        }
        
        for video in request.videos {
            guard let url = URL(string: video.url), url.scheme == "http" || url.scheme == "https" else {
                throw ValidationError.invalidVideoURL
            }
        }
    }
    
    func submitSpot(_ request: SubmitSpotRequest) async throws -> SubmitSpotResponse {
        try validateSpot(request)
        return try await APIService.shared.submitSpot(request)
    }
}

enum ValidationError: LocalizedError {
    case nameRequired
    case countryRequired
    case kindRequired
    case locationsRequired
    case invalidLocation
    case invalidLatitude
    case invalidLongitude
    case invalidLocationsFormat
    case distanceRequired
    case stateRequiredForUS
    case infoTextRequired
    case userNameRequired
    case invalidVideoURL
    
    var errorDescription: String? {
        switch self {
        case .nameRequired: return "Spot name is required"
        case .countryRequired: return "Country is required"
        case .kindRequired: return "Spot type is required"
        case .locationsRequired: return "At least one location is required"
        case .invalidLocation: return "Invalid location data"
        case .invalidLatitude: return "Latitude must be between -90 and 90"
        case .invalidLongitude: return "Longitude must be between -180 and 180"
        case .invalidLocationsFormat: return "Invalid locations format"
        case .distanceRequired: return "Distance is required for routes"
        case .stateRequiredForUS: return "State is required for US locations"
        case .infoTextRequired: return "Info text is required"
        case .userNameRequired: return "Username is required"
        case .invalidVideoURL: return "Invalid video URL"
        }
    }
}

enum SpotError: Error, LocalizedError {
    case badResponse
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "Failed to load spots. Please check your connection."
        case .invalidData:
            return "Invalid spot data received."
        }
    }
}
