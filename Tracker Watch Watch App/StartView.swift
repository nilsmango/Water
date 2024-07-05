//
//  StartView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 28.06.2024.
//

import SwiftUI

struct StartView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    @State private var showTagsSheet = false
    @State private var showWorkoutList = false
    
    var body: some View {
            VStack {
                Button(action: {
                    workoutManager.path.append("session")
                    workoutManager.startWorkout()
                    let currentWatch = WKInterfaceDevice.current()
                    currentWatch.enableWaterLock()
                    currentWatch.play(.start)
                    
                }, label: {
                    Label("Start", systemImage: "play")
                })
                .font(.title3)
                .fontWeight(.semibold)
                .tint(.green)
                .padding(.bottom)
                
                VStack {
                    Button(action: {
                        showWorkoutList = true
                    }, label: {
                        Text(workoutManager.workoutType.prettyString)
                    })
                    .tint(.orange)
                    .fontWeight(.semibold)
                    
                    HStack {
                        Button(action: {
                            showTagsSheet = true
                        }, label: {
                            Text("\(workoutManager.activeTags.count) #")
                        })
                        .tint(.accent)
                        .fontWeight(.semibold)
                        .padding(.trailing, 3)
                        
                        Button(action: {
                            workoutManager.withGPS.toggle()
                        }, label: {
                            Image(systemName: workoutManager.withGPS ? "location.fill" : "location.slash.fill")
                        })
                        .tint(workoutManager.withGPS ? .green : .red)
                        .padding(.leading, 3)
                    }
                    
                }
                .padding(.horizontal, 20)
                
            }
            .padding()
            .onAppear {
                workoutManager.requestAuthorization()
            }
            .sheet(isPresented: $showWorkoutList, content: {
                WorkoutTypeListView(workoutManager: workoutManager, showList: $showWorkoutList)
            })
            .sheet(isPresented: $showTagsSheet, content: {
                TagsSheetView(workoutManager: workoutManager, tags: $workoutManager.activeTags)
            })
        

    }
}

#Preview {
    NavigationStack {
        StartView(workoutManager: WorkoutManager())
    }
}
