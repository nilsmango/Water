//
//  WaitingForListView.swift
//  7III Tracker
//
//  Created by Simon Lang on 26.06.2024.
//

import SwiftUI

struct WaitingForListView: View {
    var body: some View {
        Section {
            
        } header: {
            
            HStack {
                Spacer()
                ProgressView("Loading Statistics")
                Spacer()
            }
            .padding(.top, 32)
        }
    }
}

#Preview {
    List {
        WaitingForListView()
    }
}
