//
//  AddMembersView.swift
//  7III Downwind
//
//  Created by Simon Lang on 14.01.24.
//

import SwiftUI

struct AddMembersView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var membersToAdd: [Member] = []
    
    @Binding var showingSheet: Bool
    
    var body: some View {
        let memberNumber = membersToAdd.count
        VStack {
            List {
                    ForEach(downwindManager.availableMembers) { member in
                        if !downwindManager.activeRun.members.contains(member) {
                            let isInRun = membersToAdd.contains(member)
                            MemberView(isInRun: isInRun, memberName: member.name)
                                .onTapGesture {
                                    if isInRun {
                                        membersToAdd.removeAll(where: { $0.id == member.id })
                                    } else {
                                        membersToAdd.append(member)
                                    }
                                }
                    }
                }
    }
            Button(action: {
                // add new members to the run
                Task {
                    do {
                        try await downwindManager.addMembersToRun(members: membersToAdd, runID: downwindManager.activeRun.id!)
                    } catch {
                        print("Error adding members to active run: \(error)")
                    }
                }
                
                // dismiss sheet
                for member in membersToAdd {
                    downwindManager.activeRun.members.append(member)
                }
                showingSheet = false
                
            }, label: {
                Label(memberNumber > 1 ? "Add Members" : "Add Member", systemImage: "plus.circle")
            })
            .disabled(memberNumber < 1)
            .buttonStyle(.bordered)
            .padding()
        }
                
    }
}

#Preview {
    AddMembersView(downwindManager: DownwindManager(), showingSheet: .constant(true))
}
