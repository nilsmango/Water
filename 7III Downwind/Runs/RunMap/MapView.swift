//
//  MapView.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2024.
//

import SwiftUI
import MapKit


struct MapView: View {
    var members: [Member]
    var user: Member
    var measurementSystem: MeasurementSystem
    
    @State private var showAlert = false
    
    var body: some View {
        Map() {
            ForEach(members) { member in
                if let latitude = member.latitude, let longitude = member.longitude {
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                        CircleAndText(member: member, measurementSystem: measurementSystem)
                    }
                }
            }
            UserAnnotation {
                CircleAndText(member: user, measurementSystem: measurementSystem)
            }
        }
    }
}

#Preview {
    MapView(members: [
        Member(id: UUID(), name: "Lay Kenny", status: "🥶🥶🥶", latitude: 47.127145, longitude: 7.220772, speed: 15.3, lastUpdated: "2024-01-21T13:36:12Z"),
        
        Member(id: UUID(), name: "Mister Bennetts", status: "Foil Flow", latitude: 47.131195, longitude: 7.231034, speed: 22.3),
        
        Member(id: UUID(), name: "Nils Mango", status: "Please Wait", latitude: 47.123295, longitude: 7.220013, speed: 1.3)
    
    ], user: Member(id: UUID(), name: "Bibi", status: "What The?", latitude: 47.123895, longitude: 7.229013, speed: 1.3, onlyWatching: false), measurementSystem: .metric)
}
