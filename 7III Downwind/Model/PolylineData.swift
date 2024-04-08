//
//  PolylineData.swift
//  7III Location
//
//  Created by Simon Lang on 08.04.2024.
//

import Foundation
import SwiftUI
import MapKit

struct PolylineData: Identifiable {
    var id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let strokeColor: Color
}
