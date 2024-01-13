//
//  FirstTimeUserNameSet.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI

struct FirstTimeUserNameSet: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var userName = ""
    
    @FocusState private var editorIsFocused: FocusField?
    
    enum FocusField: Hashable {
        case field
      }
    
    var body: some View {

        List {
            Section {
                
                TextField("Kai Lenny Junior", text: $userName)
                    .focused($editorIsFocused, equals: .field)
                    .onAppear() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {  // making the text field focussed when it appears
                            editorIsFocused = .field
                        }
                    }

            } header: {
                Text("Set a name so your friends to see")
            } footer: {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        downwindManager.user = Member(id: UUID(), name: userName)
                        downwindManager.saveUser()
                        Task {
                            do {
                                try await downwindManager.addUserToDB()
                            } catch {
                                print("Error adding user to db: \(error)")
                            }
                            do {
                                try await downwindManager.loadAllRuns()
                            } catch {
                                print("Error loading active run: \(error)")
                            }
                        }
                        
                    }, label: {
                        Label("Save", systemImage: "checkmark.circle")
                    })
                    .buttonStyle(.bordered)
                    .disabled(userName == "")
                    
                    Spacer()
                }
                .padding()
            }
            
        }
        
    }
}

#Preview {
    FirstTimeUserNameSet(downwindManager: DownwindManager())
}
