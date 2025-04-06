//
//  TagsSheetView.swift
//  Tracker Watch Watch App
//
//  Created by Simon Lang on 29.06.2024.
//

import SwiftUI

struct TagsSheetView: View {
    @ObservedObject var workoutManager: WorkoutManager

    @Binding var tags: [String]
    
    @State private var newTag = ""
    @State private var showUpgradeSheet = false
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
    
    var body: some View {
        ScrollView {
            VStack {
                if workoutManager.statisticTags.count > 2 && !workoutManager.hasPurchasedPremium {
                    Button {
                        showUpgradeSheet = true
                    } label: {
                        Label("Unlimited Tags", systemImage: "lock.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                } else {
                    TextField("Add New Tag", text: $newTag)
                        .padding()
                        .onSubmit {
                            let newSafeTag = makeWordTag(newTag)
                            workoutManager.statisticTags.append(newSafeTag)
                            newTag = ""
                        }
                        .disableAutocorrection(true)
                        .onChange(of: newTag) {
                            if canMakeTag(from: newTag) {
                                let newSafeTag = makeWordTag(newTag)
                                workoutManager.statisticTags.append(newSafeTag)
                                newTag = ""
                            }
                        }
                }
                    
                                    
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
                
                ForEach(workoutManager.statisticTags.sorted(), id: \.self) { tag in
                    SelectionButtonLabel(string: tag, chosenStrings: $tags, watch: true)
                        .font(.title3)
                        .onTapGesture {
                            if tags.contains(tag) {
                                tags.removeAll(where: { $0 == tag })
                            } else {
                                tags.append(tag)
                            }
                        }
                        .onLongPressGesture {
                            WKInterfaceDevice.current().play(.success)
                            workoutManager.removeTag(tag)
                        }
                        .padding(.bottom)
                }
            }
        }
        .onAppear {
            Task {
                await workoutManager.updateCustomerProductStatus()
            }
        }
        .navigationTitle("Select Tags")
        .sheet(isPresented: $showUpgradeSheet, content: {
            NavigationStack {
                UpgradeView(workoutManager: workoutManager, showUpgradeView: $showUpgradeSheet)
            }
        })
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
