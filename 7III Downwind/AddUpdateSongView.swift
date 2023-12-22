//
//  AddUpdateSongView.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import SwiftUI

struct AddUpdateSongView: View {
    
    @ObservedObject var addUpdateSong: AddUpdateSong
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            TextField("Song Title", text: $addUpdateSong.songTitle)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button(action: {
                addUpdateSong.addUpdateAction {
                    presentationMode.wrappedValue.dismiss()
                }
            }, label: {
                Text(addUpdateSong.buttonTitle)
            })
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    AddUpdateSongView(addUpdateSong: AddUpdateSong())
}
