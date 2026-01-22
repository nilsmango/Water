//
//  InfoSectionView.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.01.2026.
//

import SwiftUI

struct InfoSectionView: View {
    @Binding var info: SpotInfo
    var onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Tag", selection: $info.tag) {
                    ForEach(InfoTag.allCases, id: \.self) { tag in
                        Text(tag.displayName).tag(tag)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            
            TextEditor(text: $info.text)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            HStack {
                TextField("Username", text: $info.userName)
                    .textFieldStyle(.roundedBorder)
                
                Spacer()
                
                TextField("User URL (optional)", text: Binding(
                    get: { info.userUrl ?? "" },
                    set: { info.userUrl = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
