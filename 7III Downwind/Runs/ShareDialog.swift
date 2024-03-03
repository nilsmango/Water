//
//  ShareDialog.swift
//  7III Downwind
//
//  Created by Simon Lang on 03.03.2024.
//

import SwiftUI

struct ShareDialog: View {
    var urlString: String
    @Binding var isShowingShareSheet: Bool
    
    var body: some View {
        ShareLink(item: (URL(string: urlString)!)) {
            Text("Link")
        }
        
        Button("QR Code") {
            isShowingShareSheet = true
        }
    }
}

#Preview {
    ShareDialog(urlString: "someurl", isShowingShareSheet: .constant(false))
}
