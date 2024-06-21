//
//  TagsEditViewStatisticCapture.swift
//  7III Location
//
//  Created by Simon Lang on 09.04.2024.
//

import SwiftUI

struct TagsEditViewStatisticCapture: View {
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
            .onAppear {
                allTags = Array(Set(trackerTags + tags)).sorted()
            }
            Group {
                HStack {
                    TextField(tags.isEmpty ? "Add a tag ..." : "Add a new tag ...", text: $newTag)
                        .focused($isFieldFocused)
                        .onSubmit {
                            isFieldFocused = true
//                            withAnimation {
                                tags.append(makeWordTag(newTag))
                                newTag = ""
                                updateAllTags()
//                            }
                        }
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .onChange(of: newTag) {
                            if canMakeTag(from: newTag) {
//                                withAnimation {
                                    tags.append(makeWordTag(newTag))
                                    newTag = ""
                                    updateAllTags()
//                                }
                                
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.uiGray)
                )
                .frame(width: UIScreen.main.bounds.width / 2)
            }
            .padding(.top)
                
                
            
        }
    }

 

#Preview {
    TagsEditViewStatisticCapture(tags: .constant(createArray()), downwindManager: DownwindManager())
}

private func createArray() -> [String] {
    var array = [String]()
    for index in 0...50 {
        array.append("#hash\(index)")
    }
    return array
}
