//
//  MapTapGesture26.swift
//  7III Tracker
//
//  Created by Simon Lang on 09.11.2025.
//

import SwiftUI
import _MapKit_SwiftUI

extension View {
    /// ios26 is not responding to Map tap gestures - this is a workaround
    func onTapGestureBugFix(_ action: @escaping (CGPoint) -> Void) -> some View {
        modifier(TapGestureModifier(action: action))
    }
}

struct TapGestureModifier: ViewModifier {
    var action: ((CGPoint) -> Void)
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.simultaneousGesture(SpatialTapGesture().onEnded { event in
                action(event.location)
            })
        }
        else {
            content.onTapGesture { location in
                action(location)
            }
        }
    }
}

extension View {
    func conditionalDragToMoveLastCoordinate(
        coordinates: Binding<[CLLocationCoordinate2D]>,
        proxy: MapProxy
    ) -> some View {
        modifier(
            DragLastCoordinateModifier(
                coordinates: coordinates,
                proxy: proxy
            )
        )
    }
}

struct DragLastCoordinateModifier: ViewModifier {
    @Binding var coordinates: [CLLocationCoordinate2D]
    let proxy: MapProxy

    @State private var dragStartLocation: CGPoint?

    func body(content: Content) -> some View {
        content
            .highPriorityGesture(
                coordinates.isEmpty
                ? nil
                : DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let last = coordinates.last else { return }

                        if dragStartLocation == nil {
                            dragStartLocation = value.startLocation
                        }

                        guard
                            let start = dragStartLocation,
                            let startCoord = proxy.convert(start, from: .local),
                            let currentCoord = proxy.convert(value.location, from: .local)
                        else { return }

                        let deltaLat = currentCoord.latitude - startCoord.latitude
                        let deltaLon = currentCoord.longitude - startCoord.longitude

                        coordinates[coordinates.count - 1] = CLLocationCoordinate2D(
                            latitude: last.latitude + deltaLat,
                            longitude: last.longitude + deltaLon
                        )

                        dragStartLocation = value.location
                    }
                    .onEnded { _ in
                        dragStartLocation = nil
                    }
            )
    }
}
