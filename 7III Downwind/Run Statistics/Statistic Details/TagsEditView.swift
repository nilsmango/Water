//
//  TagsEditView.swift
//  7III Location
//
//  Created by Simon Lang on 09.04.2024.
//

import SwiftUI

struct TagsEditView: View {
    @Binding var tags: [String]
    
    var downwindManager: DownwindManager
    
    private var trackerTags: [String] {
        downwindManager.tags
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
    
    @Binding var type: WorkoutType
    
    var withTypeEdit = false
    
    var body: some View {
        Section {
            if allTags.isEmpty {
                EmptyTagsView()
            } else {
                FlexibleView(
                    data: allTags,
                    spacing: 5,
                    alignment: .leading
                ) { tag in
                    SelectionButtonLabel(string: tag, chosenStrings: $tags)
                        .onTapGesture {
                                if tags.contains(tag) {
                                    tags.removeAll(where: { $0 == tag })
                                    updateAllTags()
                                } else {
                                        tags.append(tag)
                                        updateAllTags()
                                }
                        }
                }
            }
            
        } header: {
            if withTypeEdit {
                VStack(alignment: .leading) {
                    Text("Edit Sport")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                            Menu {
                                ForEach(WorkoutType.allCases, id: \.self) { workoutType in
                                    if workoutType != .not7IIIPaddleSport && workoutType != .not7IIISurfingSport {
                                        Button(action: {
                                            type = workoutType
                                        }) {
                                            if type == workoutType {
                                                Label(workoutType.prettyString, systemImage: "checkmark")
                                            } else {
                                                Text(workoutType.prettyString)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Text(type.prettyString)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .textCase(nil)
                            .padding(.bottom)
                            .padding(.top, -6.0)
                            
                    Text("Edit Tags")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    }
                }
                
            }
            
        .onAppear {
            allTags = Array(Set(trackerTags + tags)).sorted()
        }
        Section {
            HStack {
                TextField("Add New Tag", text: $newTag)
                    .focused($isFieldFocused)
                    .onSubmit {
                        isFieldFocused = true
                        withAnimation {
                            tags.append(makeWordTag(newTag))
                            newTag = ""
                            updateAllTags()
                        }
                    }
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onChange(of: newTag) {
                        if canMakeTag(from: newTag) {
                            withAnimation {
                                tags.append(makeWordTag(newTag))
                                newTag = ""
                                updateAllTags()
                            }
                            
                        }
                    }
                
                if !newTag.isEmpty {
                    Button {
                        newTag = ""
                        
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .accessibilityLabel(Text("Delete"))
                            .foregroundColor(.secondary)
                        
                    }
                }
            }
            
        }
    }
}

#Preview {
    List {
        
        TagsEditView(tags: .constant(createArray()), downwindManager: DownwindManager(), type: .constant(.canoe), withTypeEdit: true)
    }
}

private func createArray() -> [String] {
    var array = [String]()
    for index in 0...50 {
        array.append("#hash\(index)")
    }
    return array
}
