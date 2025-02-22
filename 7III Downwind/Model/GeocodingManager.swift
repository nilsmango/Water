//
//  GeocodingManager.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.02.2025.
//

import CoreLocation

class GeocodingManager {
    static let shared = GeocodingManager()
    private let geocoder = CLGeocoder()
    private var locationCache: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.geocoding.queue")
    private let semaphore = DispatchSemaphore(value: 1)
    
    // Cache key generator
    private func cacheKey(latitude: Double, longitude: Double) -> String {
        // Round to 3 decimal places for reasonable accuracy (100 m)
        return "\(Double(round(1000 * latitude) / 1000)),\(Double(round(1000 * longitude) / 1000))"
    }
    
    func getNameOfLocation(location: LocationData, completion: @escaping (String?) -> Void) {
        let key = cacheKey(latitude: location.latitude, longitude: location.longitude)
        
        // Check cache first
        if let cachedName = locationCache[key] {
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
                
                // Cache the result
                if let name = locationName {
                    self.locationCache[key] = name
                }
                
                completion(locationName)
            }
        }
    }
}
