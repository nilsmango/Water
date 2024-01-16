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
    
    @Binding var showingSheet: Bool
    
    enum FocusField: Hashable {
        case field
      }
    
    var body: some View {
        VStack {
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
            }
        }
            
            Button(action: {
                downwindManager.user = Member(id: UUID(), name: userName)
                downwindManager.saveUser()
                showingSheet = false
                
                Task {
                    do {
                        try await downwindManager.checkAndUpdateUserInDB()
                    } catch {
                        print("Error checking and updating user in db: \(error)")
                    }
                }
                
            }, label: {
                Label("Save", systemImage: "checkmark.circle")
            })
            .buttonStyle(.bordered)
            .disabled(userName == "")
            .padding()
        }
        .background(Color("ListBackground"))

        
    }
}

#Preview {
    FirstTimeUserNameSet(downwindManager: DownwindManager(), showingSheet: .constant(true))
}
