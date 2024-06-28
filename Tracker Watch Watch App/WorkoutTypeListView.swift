//
//  WorkoutTypeListView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct WorkoutTypeListView: View {
    @ObservedObject var workoutManager: WorkoutManager

    @Binding var showList: Bool
    
    var body: some View {
        List(WorkoutType.allCases, id: \.self) { type in
            if type != .not7IIIPaddleSport && type != .not7IIISurfingSport {
                Button(action: {
                    workoutManager.workoutType = type
                    showList = false
                }) {
                    HStack {
                        Spacer()
                        
                        Text(type.prettyString)
                            .bold(type == workoutManager.workoutType ? true : false)
                        
                        Spacer()
                    }
                    
                }
                .padding()
            }
        }
        .listStyle(.carousel)
    }
}

#Preview {
    WorkoutTypeListView(workoutManager: WorkoutManager(), showList: .constant(true))
}
