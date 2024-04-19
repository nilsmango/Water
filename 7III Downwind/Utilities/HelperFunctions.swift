//
//  HelperFunctions.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import Foundation
import SwiftUI
import CoreImage.CIFilterBuiltins

func createDWURL(endpoint: String) throws -> URL {
    let urlString = Constants.baseURL + endpoint
    
    guard let url = URL(string: urlString) else {
        throw HTTPError.badURL
    }
    
    return url
}

// TODO: Remove this
func createSongURL() throws -> URL {
    let urlString = Constants.baseURL + Endpoints.songs
    
    guard let url = URL(string: urlString) else {
        throw HTTPError.badURL
    }
    
    return url
}

func dateFromString(_ dateString: String) -> Date? {
    let dateFormatter = ISO8601DateFormatter()
//    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]

    return dateFormatter.date(from: dateString)
}

func generateQRCode(from string: String) -> UIImage {
    let data = Data(string.utf8)
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    filter.setValue(data, forKey: "inputMessage")
    
    if let outputImage = filter.outputImage {
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return UIImage(systemName: "xmark.circle") ?? UIImage()
}


/// decoding sample location data
func decodeLocationSampleData() -> [LocationData]? {
    if let url = Bundle.main.url(forResource: "locationData", withExtension: "json") {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let locations = try decoder.decode([LocationData].self, from: data)
            return locations
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    return nil
}


/// making a string work as an URL by replacing strings with %20
func replaceSpacesInString(input: String) -> String {
    return input.replacingOccurrences(of: " ", with: "%20")
}

/// creates a string from an url
func makeURLToRunName(url: URL) -> String {
    let stringFromURL = url.absoluteString
    let rawRunName = stringFromURL.replacingOccurrences(of: Constants.deepLinkBase, with: "")
    return rawRunName.replacingOccurrences(of: "%20", with: " ")
}
