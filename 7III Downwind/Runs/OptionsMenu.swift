//
//  OptionsMenu.swift
//  7III Downwind
//
//  Created by Simon Lang on 11.01.24.
//

import SwiftUI

struct OptionsMenu: View {
    var onlyWatching: Bool
    
    @Binding var sorting: RunListSorting
    @Binding var measurement: MeasurementSystem
    @Binding var showListDetail: Bool
    @Binding var isShowingShareSheet: Bool
    @Binding var isShowingOtherSheet: Bool
    
    var body: some View {
        Menu {

            Menu {
                Picker("Measurement System", selection: $measurement) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.rawValue)
                    }
                }
            } label: {
                Label("Measurement System", systemImage: "ruler")
            }
            if !onlyWatching {
                Menu {
                    Toggle(isOn: $showListDetail, label: {
                        Text("Show List Details")
                    })
                } label: {
                    Text("Show List Details")
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
            }
            
            Button {
                isShowingOtherSheet = true
                
            } label: {
                if onlyWatching {
                    Label("Show Coordinates", systemImage: "globe")
                } else {
                    Label("Show Map", systemImage: "map")
                }
            }
            
            Button {
                isShowingShareSheet = true
                
            } label: {
                Label("Share Run", systemImage: "square.and.arrow.up")
            }
            
            
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }
}

#Preview {
    OptionsMenu(onlyWatching: true, sorting: .constant(.distanceAscending), measurement: .constant(.metric), showListDetail: .constant(true), isShowingShareSheet: .constant(true), isShowingOtherSheet: .constant(false))
}
