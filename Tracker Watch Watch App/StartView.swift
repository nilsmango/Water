//
//  StartView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct StartView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    @State private var showWorkoutList = false
    
    var body: some View {
            VStack {
                Button(action: {
                    workoutManager.path.append("session")
                    workoutManager.startWorkout()
                }, label: {
                    Label("Start", systemImage: "play")
                })
                .font(.title3)
                .tint(.green)
                .padding(.bottom)
                
                VStack {
                    // TODO: make it real
                    Button(action: {
                        showWorkoutList = true
                    }, label: {
                        Text(workoutManager.workoutType.prettyString)
                    })
                    .tint(.orange)
                    
                    // TODO: tags
                    Button(action: {
                        // showTagsList = true
                    }, label: {
                        // Text("Tags: \(tags.count")
                        Text("Tags: 3")
                    })
                    .tint(.accent)
                }
                .padding(.horizontal, 22)
                
            }
//                    .navigationTitle("7III Tracker")
        //            .navigationBarTitleDisplayMode(.inline)
            .padding()
            .onAppear {
                workoutManager.requestAuthorization()
            }
        
            .sheet(isPresented: $showWorkoutList, content: {
                WorkoutTypeListView(workoutManager: workoutManager, showList: $showWorkoutList)
            })
            
        

    }
}

#Preview {
    NavigationStack {
        StartView(workoutManager: WorkoutManager())
    }
}
