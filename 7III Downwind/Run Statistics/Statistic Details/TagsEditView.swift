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
    
    @State private var allTags = [String]()
    
    @State private var newTag = ""
    @State private var firstLocation = ""
    @State private var secondLocation = ""
    
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
    
    private func extractLocations() {
        let components = locationString.components(separatedBy: "→").map { $0.trimmingCharacters(in: .whitespaces) }
        firstLocation = components.first ?? ""
        secondLocation = components.count > 1 ? components[1] : invisibleLocation
    }
    
    @Binding var type: WorkoutType
    @Binding var locationString: String
    
    var withTypeEdit = false
    
    let invisibleLocation = "Zerothing"
    
    var body: some View {
        if withTypeEdit {
            Section {
                VStack {
                    HStack {
                        //                    Label("", systemImage: "location.fill")
                        //                        .padding(.trailing, -10)
                        
                        TextField("Start Location", text: $firstLocation)
                        
                        Group {
                            Text("→")
                            TextField("End Location", text: $secondLocation)
                        }
                        .opacity(secondLocation != invisibleLocation ? 1 : 0)
                        
                        Spacer()
                    }
                    .onChange(of: firstLocation) { oldValue, newValue in
                        if locationString.contains("→") {
                            locationString = [newValue, secondLocation].map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " → ")
                            
                        } else {
                            locationString = newValue.trimmingCharacters(in: .whitespaces)
                        }
                    }
                    .onChange(of: secondLocation) { oldValue, newValue in
                        if newValue == invisibleLocation || newValue == "" {
                            locationString = firstLocation.trimmingCharacters(in: .whitespaces)
                        } else {
                            locationString = [firstLocation, newValue].map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " → ")
                        }
                        
                    }
                    
                    HStack {
                        if secondLocation != invisibleLocation {
                            Button {
                                secondLocation = invisibleLocation
                            } label: {
                                Text("Remove End Location")
                                
                            }
                            
                        } else {
                            Button {
                                secondLocation = ""
                            } label: {
                                Text("Add End Location")
                            }
                        }
                        
                        
                        Spacer()
                    }
                    .buttonStyle(.bordered)
                    .tint(.accent)
                    
                    if !downwindManager.locationStrings.isEmpty {
                        HStack {
                            
                            Menu {
                                ForEach(downwindManager.locationStrings, id: \.self) { string in
                                    
                                    Button(action: {
                                        locationString = string
                                        extractLocations()
                                    }) {
                                        Text(string)
                                        
                                    }
                                }
                            } label: {
                                Text("Use Existing Location")
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                            
                            Spacer()
                        }
                    }
                }
            } header: {
                
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
                    
                    Text("Edit Location")
                        .textCase(nil)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                }
            }
        }
        
        
        
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
            Text("Edit Tags")
                .textCase(nil)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, -6.0)
        }
        .onAppear {
            extractLocations()
            updateAllTags()
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
        
        TagsEditView(tags: .constant(createArray()), downwindManager: DownwindManager(), type: .constant(.canoe), locationString: .constant("Concise → Murten"), withTypeEdit: true)
    }
}

private func createArray() -> [String] {
    var array = [String]()
    for index in 0...50 {
        array.append("#hash\(index)")
    }
    return array
}
