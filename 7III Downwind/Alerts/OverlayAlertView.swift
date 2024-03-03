//
//  OverlayAlertView.swift
//  7III Downwind
//
//  Created by Simon Lang on 06.01.24.
//

import SwiftUI

struct OverlayAlertView: View {

    @Binding var showAlert: Bool
    
    var text: String
    var showSymbol: Bool = true
    var symbolPositive = false
    var padding: Double = 16.0
    
    var body: some View {
        if showAlert {
            VStack {
                HStack {
                    if showSymbol {
                        Image(systemName: symbolPositive ? "checkmark" : "exclamationmark.triangle")
                    }
                    Text(text)
                }
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                
                .padding(padding)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(.dwGray)
//                        .background(.ultraThinMaterial)
                }
                .onTapGesture {
                    showAlert = false
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        showAlert = false
                    }
                }
            }
            .padding()
            .frame(width: UIScreen.main.bounds.width * 0.8)
//            .background(StartView())
            .outsideTap {
                showAlert = false
            }
        }
            
    }
}

#Preview {
    OverlayAlertView(showAlert: .constant(true), text: "Cute Alert!")
}
