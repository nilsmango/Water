//
//  TagsSheetView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 29.06.2024.
//

import SwiftUI

struct TagsSheetView: View {
    var workoutManager: WorkoutManager
    
    @Binding var tags: [String]
    
    private var trackerTags: [String] {
        workoutManager.statisticTags
    }
    
    @State private var allTags = [String]()
    
    @State private var newTag = ""
    
    @FocusState private var isFieldFocused: Bool
    
    private func makeWordTag(_ word: String) -> String {
        let cleanWord = word.trimmingCharacters(in: .whitespaces)
        if cleanWord.hasPrefix("#") {
            return cleanWord
        } else {
            return "#" + cleanWord
        }
    }
    
    private func canMakeTag(from word: String) -> Bool {
        if word.hasSuffix(" ") || word.hasSuffix("\n") {
            return true
        } else {
            return false
        }
    }
    
    private func updateAllTags() {
        allTags = Array(Set(trackerTags + tags)).sorted()
    }
    
    var body: some View {
        ScrollView {
            VStack {
                TextField("Add New Tag", text: $newTag)
                    .onSubmit {
                        tags.append(makeWordTag(newTag))
                        newTag = ""
                        updateAllTags()
                    }
                    .disableAutocorrection(true)
                    .onChange(of: newTag) {
                        if canMakeTag(from: newTag) {
                            tags.append(makeWordTag(newTag))
                            newTag = ""
                            updateAllTags()
                        }
                    }
                                    .padding()
                                    
//                Button(action: {
//                    // TODO: open keyboard for text
//                }, label: {
//                    Label("Add Tag", systemImage: "plus")
//                        .fontWeight(.semibold)
//                        .font(.title3)
//                        
//                })
//                .tint(.accent)
//                .padding(.vertical)
                
                ForEach(allTags, id: \.self) { tag in
                    SelectionButtonLabel(string: tag, chosenStrings: $tags, watch: true)
                        .font(.title3)
                        .onTapGesture {
                            if tags.contains(tag) {
                                tags.removeAll(where: { $0 == tag })
                                updateAllTags()
                            } else {
                                tags.append(tag)
                                updateAllTags()
                            }
                        }
                        .padding(.bottom)
                }
            }
        }
        .onAppear {
            allTags = Array(Set(trackerTags + tags)).sorted()
        }
        .navigationTitle("Select Tags")
    }
}

#Preview {
    NavigationStack {
        
        TagsSheetView(workoutManager: PreviewWorkoutManager(), tags: .constant(["#running"]))
    }
}


class PreviewWorkoutManager: WorkoutManager {
    override init() {
        super.init()
        self.statisticTags = ["#running", "#yoga", "#strength"]
    }
}
