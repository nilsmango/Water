//
//  GenerateQRCode.swift
//  7III Tracker
//
//  Created by Simon Lang on 27.06.2024.
//

import Foundation
import CoreImage.CIFilterBuiltins
import UIKit


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
