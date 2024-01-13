//
//  NewRunView.swift
//  7III Downwind
//
//  Created by Simon Lang on 07.01.24.
//

import SwiftUI

struct NewRunView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @Binding var showSheet: Bool
    @State private var runName: String = ""
    @State private var runMembers: [Member] = []
    
    @FocusState private var editorIsFocused: FocusField?
    
    enum FocusField: Hashable {
        case field
      }
    
    var body: some View {
        List {
            Section("Run Name") {

                TextField("Enter run name here", text: $runName)
                    .focused($editorIsFocused, equals: .field)
                    .onAppear() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {  // making the text field focussed when it appears
                            editorIsFocused = .field
                        }
                    }
            }
            Section {
                
                if downwindManager.availableMembers == [] {
                    Text("No members found")
                    
                } else {
                    ForEach(downwindManager.availableMembers) { member in
                        let isInRun = runMembers.contains(member)
                        HStack {
                            Image(systemName: isInRun ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isInRun ? .blue : .primary)
                            Text(member.name)
                        }
                        .onTapGesture {
                            if isInRun {
                                runMembers.removeAll(where: { $0.id == member.id })
                            } else {
                                runMembers.append(member)
                            }
                        }
                    }
                }
                
            } header: {
                Text("Select Members")
            } footer: {
                // put the button in the footer so the list looks great.
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if runName.isEmpty {
                            runName = "Generic Run \(Int.random(in: 1...999))"
                        }
                        // adding the user to the members.
                        runMembers.append(downwindManager.user)
                        showSheet = false
                        
                        // upload the new run, then load the active run from the db
                        Task {
                            do {
                                try await downwindManager.startNewRun(name: runName, members: runMembers)
                                try await downwindManager.loadAllRuns()
                            } catch {
                                print("Error: \(error)")
                            }
                        }
                        
                        
                        
                    }, label: {
                        Label("Start Run", systemImage: "wind")
                    })
                    .buttonStyle(.bordered)
                    .disabled(runMembers.count < 2)
                    
                    Spacer()
                }
                .padding()
                
            }
            
            
        }
    }
    
}

#Preview {
    
    NewRunView(downwindManager: DownwindManager(), showSheet: .constant(true))
}
