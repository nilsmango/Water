//
//  Extensions.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.01.24.
//

import Foundation
import CoreLocation


extension Double {
    var radiansToDegrees: Double {
        return self * 180.0 / .pi
    }
}

extension Double {
    var degreesToRadians: Double {
        return self * .pi / 180.0
    }
}
