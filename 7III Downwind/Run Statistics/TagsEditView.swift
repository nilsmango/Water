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
    
    var body: some View {
        Section {
            FlexibleView(
                data: allTags,
                spacing: 5,
                alignment: .leading
            ) { tag in
                SelectionButtonLabel(string: tag, chosenStrings: $tags, allStrings: trackerTags)
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
        .onAppear {
            allTags = Array(Set(trackerTags + tags)).sorted()
        }
        Section {
            HStack {
                TextField("Add a new tag ...", text: $newTag)
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
//    List {
        
        TagsEditView(tags: .constant(["#140p", "#bise"]), downwindManager: DownwindManager())
//    }
}
