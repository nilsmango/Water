//
//  OverlayAlertView.swift
//  7III Downwind
//
//  Created by Simon Lang on 06.01.24.
//

import SwiftUI

struct OverlayAlertView: View {
    @Binding var locationError: LocationError
    
    var body: some View {
        if locationError == .notPossible {
            VStack {
                
                Text("""
                    Can't activate location services.
                    Either your device is in Airplane mode or the device doesn’t have the required hardware.
                    Please deactivate Airplane mode and try again.
                    """)
                
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(.gray.opacity(0.5))
                    //                        .background(.ultraThinMaterial)
                }
                .onTapGesture {
                    locationError = .none
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        locationError = .none
                    }
                }
            }
            .padding()
            .frame(width: UIScreen.main.bounds.width * 0.8)
        }
    }
}

#Preview {
    OverlayAlertView(locationError: .constant(.notPossible))
}
