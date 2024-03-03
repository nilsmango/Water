//
//  QRCodeView.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.03.2024.
//

import SwiftUI

struct QRCodeView: View {
    var qrString: String
    
    var body: some View {
        Image(uiImage: generateQRCode(from: qrString))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    QRCodeView(qrString: "\(Constants.deepLinkBase)testing")
}
