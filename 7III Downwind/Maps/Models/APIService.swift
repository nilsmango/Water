//
//  APIService.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://project7iii.com/foildata/map/"
    private let apiKey: String
    
    private init() {
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String ?? ""
        
        if apiKey.isEmpty {
            print("⚠️ WARNING: API_KEY not found in Info.plist. Spot submission will fail.")
        }
    }
    
    func submitSpot(_ request: SubmitSpotRequest) async throws -> SubmitSpotResponse {
        guard let url = URL(string: baseURL + "submit-spot-ios.php") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SubmitSpotResponse.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 400...499:
            if let errorResponse = try? JSONDecoder().decode(SubmitSpotResponse.self, from: data) {
                throw APIError.clientError(errorResponse.message ?? "Unknown client error")
            }
            throw APIError.clientError("Invalid request")
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case noResponse
    case unauthorized
    case clientError(String)
    case serverError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .noResponse:
            return "No response from server"
        case .unauthorized:
            return "Unauthorized: Invalid API key"
        case .clientError(let message):
            return message
        case .serverError:
            return "Server error. Please try again later."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
