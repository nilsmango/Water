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
    
    var body: some View {
        List {
            Section("Set a name so your friends to see") {
            TextField("Kai Lenny Junior", text: $userName)
        
            Button(action: {
                downwindManager.user = Member(id: UUID(), name: userName)
                downwindManager.saveUser()
                Task {
                    do {
                        try await downwindManager.addUserToDB()
                        
                    } catch {
                        print("Error: \(error)")
                    }
                }
                
            }, label: {
                Text("Save")
            })
            .disabled(userName == "")
            }
        }
    }
}

#Preview {
    FirstTimeUserNameSet(downwindManager: DownwindManager())
}
