//
//  OptionsMenu.swift
//  7III Downwind
//
//  Created by Simon Lang on 11.01.24.
//

import SwiftUI

struct OptionsMenu: View {
    
    @Binding var sorting: RunListSorting
    @Binding var measurement: MeasurementSystem
    @Binding var showAdMembersView: Bool
    
    var body: some View {
        Menu {
            Button(action: {
                showAdMembersView = true
            }, label: {
                Label("Add Members", systemImage: "plus.circle")
            })
            
            Menu {
                Picker("Measurement System", selection: $measurement) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.rawValue)
                    }
                }
            } label: {
                Label("Measurement System", systemImage: "ruler")
            }
            
            Menu {
                Picker("Sorting", selection: $sorting) {
                    ForEach(RunListSorting.allCases) { sortCase in
                        Text(sortCase.rawValue)
                    }
                }
            }
        label: {
            Label("List Sorting", systemImage: "arrow.up.arrow.down")
        }
            
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }
}

#Preview {
    OptionsMenu(sorting: .constant(.distanceAscending), measurement: .constant(.metric), showAdMembersView: .constant(false))
}
