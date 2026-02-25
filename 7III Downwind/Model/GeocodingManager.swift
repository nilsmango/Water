//
//  GeocodingManager.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.02.2025.
//

import CoreLocation

struct GeocodedLocationInfo: Codable {
    let name: String?
    let thoroughfare: String?
    let locality: String?
    let countryCode: String?
    let state: String?
}

class GeocodingManager {
    static let shared = GeocodingManager()
    private let geocoder = CLGeocoder()
    private var locationCache: [String: GeocodedLocationInfo] = [:]
    private let queue = DispatchQueue(label: "com.geocoding.queue", qos: .utility)
    private let semaphore = DispatchSemaphore(value: 1)
    private let cacheFileName = "geocodingCache.json"
    
    private init() {
        loadCacheFromDisk()
    }
    
    private func cacheKey(latitude: Double, longitude: Double) -> String {
        // Round to 3 decimal places for reasonable accuracy (100 m)
        return "\(Double(round(1000 * latitude) / 1000)),\(Double(round(1000 * longitude) / 1000))"
    }
    
    // Helper method to get documents directory
    private func getDocumentsDirectory() throws -> URL {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            fatalError("Can't find documents directory.")
        }
    }
    
    // Load cache from disk
    private func loadCacheFromDisk() {
        do {
            let url = try getDocumentsDirectory().appendingPathComponent(cacheFileName)
            let data = try Data(contentsOf: url)
            let decodedCache = try JSONDecoder().decode([String: GeocodedLocationInfo].self, from: data)
            locationCache = decodedCache
        } catch {
            print("Error loading geocoding cache: \(error)")
            locationCache = [:]
        }
    }
    
    // Save cache to disk
    private func saveCacheToDisk() {
        do {
            let data = try JSONEncoder().encode(locationCache)
            let url = try getDocumentsDirectory().appendingPathComponent(cacheFileName)
            try data.write(to: url)
        } catch {
            print("Error saving geocoding cache: \(error)")
        }
    }
    
    func getNameOfLocation(location: LocationData, completion: @escaping (String?) -> Void) {
        let key = cacheKey(latitude: location.latitude, longitude: location.longitude)
        
        // Check cache first
        if let cachedInfo = locationCache[key], let cachedName = cachedInfo.locality {
            completion(cachedName)
            return
        }
        
        queue.async {
            // Wait for semaphore
            self.semaphore.wait()
            
            // Add 1.2 second delay between requests to stay under rate limit
            Thread.sleep(forTimeInterval: 1.2)
            
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                defer {
                    self.semaphore.signal()
                }
                
                guard let placemark = placemarks?.first, error == nil else {
                    completion(nil)
                    return
                }
                
                let locationName = placemark.locality
                
                // Cache the result and persist to disk
                if let name = locationName {
                    let info = GeocodedLocationInfo(name: nil, thoroughfare: nil, locality: name, countryCode: nil, state: nil)
                    self.locationCache[key] = info
                    self.saveCacheToDisk()
                }
                
                completion(locationName)
            }
        }
    }
    
    func getDetailsOfLocation(location: LocationData, completion: @escaping (GeocodedLocationInfo) -> Void) {
        let key = cacheKey(latitude: location.latitude, longitude: location.longitude)
        
        // Check cache first - return full details if cached
        if let cachedInfo = locationCache[key] {
            completion(cachedInfo)
            return
        }
        
        queue.async {
            // Wait for semaphore
            self.semaphore.wait()
            
            // Add 1.2 second delay between requests to stay under rate limit
            Thread.sleep(forTimeInterval: 1.2)
            
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                defer {
                    self.semaphore.signal()
                }
                
                guard let placemark = placemarks?.first, error == nil else {
                    completion(GeocodedLocationInfo(name: nil, thoroughfare: nil, locality: nil, countryCode: nil, state: nil))
                    return
                }
                
                let locationName = placemark.name
                let thoroughfare = placemark.thoroughfare
                let locality = placemark.locality
                let countryCode = placemark.isoCountryCode
                let state = placemark.administrativeArea
                
                // Cache all details and persist to disk
                let info = GeocodedLocationInfo(name: locationName, thoroughfare: thoroughfare, locality: locality, countryCode: countryCode, state: state)
                self.locationCache[key] = info
                self.saveCacheToDisk()
                
                completion(info)
            }
        }
    }
}
