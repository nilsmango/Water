//
//  RunShareView.swift
//  7III Downwind
//
//  Created by Simon Lang on 16.01.2024.
//

import SwiftUI

struct RunShareView: View {
    var runName: String
    
    var body: some View {
        VStack {
            
            QRCodeView(qrString: Constants.deepLinkBase + runName)
            .padding()
            
            Text(runName)
                .textSelection(.enabled)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.dwGray)
                }
        }
    }
}

#Preview {
    RunShareView(runName: "testing")
}
