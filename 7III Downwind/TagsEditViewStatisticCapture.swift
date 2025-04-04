//
//  TagsEditViewStatisticCapture.swift
//  7III Location
//
//  Created by Simon Lang on 09.04.2024.
//

import SwiftUI

struct TagsEditViewStatisticCapture: View {
    @Binding var tags: [String]
    
    @ObservedObject var downwindManager: DownwindManager
    
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
        allTags = Array(Set(downwindManager.tags + tags)).sorted()
    }
    
    var body: some View {
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
        
        Group {
            if allTags.count > 3 && !downwindManager.hasPurchasedPremium {
                Button {
                    downwindManager.showUpgradeSheet = true
                } label: {
                    Label("Unlimited Tags", systemImage: "lock.fill")
                }
                .buttonStyle(.borderedProminent)
                
            } else {
            HStack {
                TextField("Add New Tag", text: $newTag)
                    .focused($isFieldFocused)
                    .onSubmit {
                            isFieldFocused = true
                            tags.append(makeWordTag(newTag))
                            newTag = ""
                            updateAllTags()
                    }
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onChange(of: newTag) {
                        if canMakeTag(from: newTag) {
                            tags.append(makeWordTag(newTag))
                            newTag = ""
                            updateAllTags()
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
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(.uiGray)
            )
            .frame(width: UIScreen.main.bounds.width / 2)
        }
        }
        .padding(.top)
        .onAppear {
            updateAllTags()
        }
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
