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
    @AppStorage("refreshInterval") private var refreshInterval: TimeInterval = 6 * 60 * 60
    
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
        if let cachedSpots = loadFromCache() {
            self.spots = cachedSpots
        }
        
        if shouldRefresh() {
            await fetchSpotsFromServer()
        }
    }
    
    func refreshSpots() async {
        await fetchSpotsFromServer()
    }
    
    private func fetchSpotsFromServer() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (data, response) = try await URLSession.shared.data(from: spotsURL)
            
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
    
    private func loadFromCache() -> [Spot]? {
        guard !spotsData.isEmpty else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Spot].self, from: spotsData)
        } catch {
            print("Failed to decode cached spots: \(error)")
            return nil
        }
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
