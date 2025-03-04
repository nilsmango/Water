//
//  StringSelectionView.swift
//  7III Tracker
//
//  Created by Simon Lang on 22.02.2025.
//

import SwiftUI

struct StringSelectionView: View {
    let allStrings: [String]
    @Binding var chosenString: String
    var isLocations: Bool = false
    
    var body: some View {
        if allStrings.isEmpty {
            ScrollView {
                Text(isLocations ? "Record a workout to display its location here." : "Record an workout to display it here.")
                    .foregroundStyle(.secondary)
            }
        } else {
            List {
                ForEach(allStrings, id: \.self) { string in
                        HStack {
                            if chosenString == string {
                                Image(systemName: "checkmark")
                            }
                            Text(string)
                            Spacer()
                        }
                        .foregroundStyle(chosenString == string ? .accent : .primary)
                        .fontWeight(chosenString == string ? .bold : .regular)
                        .contentShape(.rect)
                    
                    .onTapGesture {
                        if chosenString == string {
                            chosenString = ""
                        } else {
                            chosenString = string
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        
    }
}

#Preview {
    StringSelectionView(allStrings: ["Lake", "Mountain", "Sea"], chosenString: .constant("Lake"))
}
