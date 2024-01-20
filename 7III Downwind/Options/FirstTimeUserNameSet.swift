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
    @State private var status = ""
    
    @Binding var showingSheet: Bool
    
    
    var body: some View {
        VStack {
            List {
                Section {
                    TextField("Kai Lenny", text: $userName)
                        .onChange(of: userName, { oldValue, newValue in
                            if newValue.count > Constants.maxLengthUser {
                                userName = String(newValue.prefix(Constants.maxLengthUser))
                            }
                        })

                } header: {
                    Text("Set a name so your friends to see")
                }
                
                Section {
                    TextField("Frothing!", text: $status)
                        .onChange(of: status, { oldValue, newValue in
                            if newValue.count > Constants.maxLengthUser {
                                status = String(newValue.prefix(Constants.maxLengthUser))
                            }
                        })
                } header: {
                    Text("Set a status")
                }
            }
            
            Button(action: {
                downwindManager.user = Member(id: UUID(), name: userName, status: status)
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
            .disabled(userName == "" || status == "")
            .padding()
        }
        .background(Color("ListSheet"))

        
    }
}

#Preview {
    FirstTimeUserNameSet(downwindManager: DownwindManager(), showingSheet: .constant(true))
}
