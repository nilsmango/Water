//
//  OptionsMenu.swift
//  7III Downwind
//
//  Created by Simon Lang on 11.01.24.
//

import SwiftUI

struct OptionsMenu: View {
    @Binding var onlyWatching: Bool?
    @Binding var sorting: RunListSorting
    @Binding var measurement: MeasurementSystem
    @Binding var showListDetail: Bool
    @Binding var isShowingShareSheet: Bool
    @Binding var isShowingOtherSheet: Bool
    
    var changingRunStatus: () -> Void
    
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
            if !(onlyWatching ?? false) {
                Menu {
                    Toggle(isOn: $showListDetail, label: {
                        Text("Show List Details")
                    })
                } label: {
                    Label("Show List Details", systemImage: "text.magnifyingglass")
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
            
            if !(onlyWatching ?? false) {
                Button {
                    // change status of user
                    onlyWatching = false
                    // stop timer and upload nil location + onlyWatching
                    // start new timer with only downloading.
                    changingRunStatus()
                    
                } label: {
                    Label("Switch to Watching", systemImage: "eyes")
                }
            }
            
            Button {
                isShowingOtherSheet = true
                
            } label: {
                if onlyWatching ?? false {
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
    OptionsMenu(onlyWatching: .constant(false), sorting: .constant(.distanceAscending), measurement: .constant(.metric), showListDetail: .constant(true), isShowingShareSheet: .constant(true), isShowingOtherSheet: .constant(false), changingRunStatus: {})
}
