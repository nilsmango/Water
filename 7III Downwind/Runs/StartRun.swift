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
    
    var isNewRun: Bool
    
    @FocusState private var editorIsFocused: FocusField?
    
    enum FocusField: Hashable {
        case field
      }
    
    @State private var showAlert = false
    @State private var alertText = ""
    
    var body: some View {
        VStack {
            List {
                
                Section {

                    TextField(isNewRun ? "Enter new run name here" : "Enter run to join here", text: $runName)
                        .focused($editorIsFocused, equals: .field)
                        .onAppear() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {  
                                // making the text field focussed when it appears
                                editorIsFocused = .field
                            }
                        }
                } header: {
                    Text("Run Name")
                }
            }
            
            Button(action: {
                if isNewRun {
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
                } else {
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
                }
                
            }, label: {
                Label(isNewRun ? "Start Run" : "Join Run", systemImage: isNewRun ? "wind.snow" : "wind")
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
    
    StartRun(downwindManager: DownwindManager(), showSheet: .constant(true), isNewRun: false)
}
