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
            Text("Loading Statistics...")
        } header: {
            Text("Hang loose!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .textCase(nil)
        }
    }
}

#Preview {
    List {
        WaitingForListView()
    }
}
