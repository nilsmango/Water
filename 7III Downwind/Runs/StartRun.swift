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
                        .focused($editorIsFocused, equals: .field)
                        .onAppear() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {  
                                // making the text field focussed when it appears
                                editorIsFocused = .field
                            }
                        }
                        .onChange(of: runName) { oldValue, newValue in
                                        // Filter out characters that won't work in a URL
                                        let filteredText = newValue.filter { character in
                                            character.isLetter || character.isNumber || character.isWhitespace ||
                                                                character == "-" || character == "." || character == "_"
                                        }
                                        
                                        runName = filteredText
                                    }
                } header: {
                    Text("Run Name")
                } footer: {
                    if runType == .start {
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                runName = downwindManager.createRandomRunName()
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
            
            Button(action: {
                switch runType {
                case .start:
                    // start a new run and add yourself, load and update active run
                    Task {
                        do {
                            try await downwindManager.startNewRun(name: runName)
                        } catch {
                            print("Error starting new run: \(error)")
                            alertText = """
                            Error starting new run.
                            Make sure you are connected to the internet.
                            """
                            showAlert = true
                        }
                    }
                case .join:
                    // if not in db show "no run with that name is running at the moment"
                    
                    // if everything works out add yourself to the run and load and update active run
                    Task {
                        do {
                            try await downwindManager.joinRun(name: runName)
                        } catch GetRunError.badResponse {
                            alertText = "No run with that name found!"
                            showAlert = true
                        } catch {
                            alertText = "Error joining run: \(error)"
                            showAlert = true
                        }
                    }
                case .watch:
                    Task {
                        do {
                            try await downwindManager.watchRun(name: runName)
                        } catch GetRunError.badResponse {
                            alertText = "No run with that name found!"
                            showAlert = true
                        } catch {
                            alertText = "Error joining run: \(error)"
                            showAlert = true
                        }
                    }
                }
                
                
            }, label: {
                Label(runType.buttonLabel, systemImage: runType.symbol)
            })
            .buttonStyle(.bordered)
            .disabled(runName == "")
            .padding()
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
