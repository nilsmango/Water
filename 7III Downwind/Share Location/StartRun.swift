//
//  StartRun.swift
//  7III Downwind
//
//  Created by Simon Lang on 07.01.24.
//

import SwiftUI

struct StartRun: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showSheet: Bool
    @State private var runName: String = ""
    
    var runType: RunType
    
    @FocusState private var editorIsFocused: FocusField?
    
    enum FocusField: Hashable {
        case field
      }
    
    @State private var showAlert = false
    @State private var alertText = ""
    
    @State private var showShareDialog = false
    
    var body: some View {
        VStack {
            List {
                
                Section {

                    TextField(runType.textFieldText, text: $runName)
//                        .focused($editorIsFocused, equals: .field)
//                        .onAppear() {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {  
//                                // making the text field focussed when it appears
//                                editorIsFocused = .field
//                            }
//                        }
//                        .onChange(of: runName) { oldValue, newValue in
//                            // Filter out characters that won't work in a URL
//                            let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._").union(.whitespaces)
//                            
//                            let filteredText = newValue.filter { character in
//                                allowedCharacterSet.contains(character.unicodeScalars.first!)
//                            }
//                            
//                            runName = filteredText
//                        }
                } header: {
                    Text("Run Name")
                } footer: {
                    if runType == .start {
                        HStack {
                            Spacer()
                            
                            Button(action: {
//                                runName = downwindManager.createRandomRunName()
                            }, label: {
                                Label("Create Random Name", systemImage: "dice.fill")
                            })
                            .buttonStyle(.bordered)
                            
                            Spacer()

                        }
                        .padding()
                        
                    }
                }
            }
            
            
                
                
                
                
            
        }
        .background(.listSheet)
        .overlay {
            OverlayAlertView(showAlert: $showAlert, text: alertText)
        }
        
    }
    
}

#Preview {
    
    StartRun(downwindManager: DownwindManager(), showSheet: .constant(true), runType: .start)
}
