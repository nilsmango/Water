//
//  SongList.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import SwiftUI

struct SongList: View {
    @StateObject var songData = SongData()
    
    @State var modal: ModalType? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(songData.songs) { song in
                    Button(action: {
                        modal = .update(song)
                    }, label: {
                        Text(song.title)
                            .font(.title3)
                    })
                }
                .onDelete(perform: songData.delete)
            }
            .navigationTitle("Songs")
            .toolbar {
                Button(action: {
                    modal = .add
                }, label: {
                    Label("Add Song", systemImage: "plus.circle")
                })
            }
        }
        .sheet(item: $modal, onDismiss: {
            Task {
                do {
                    try await songData.fetchSongs()
                } catch {
                    print("Error: \(error)")
                }
            }
        }) { modal in
            switch modal {
            case .add:
                AddUpdateSongView(addUpdateSong: AddUpdateSong())
            case .update(let song):
                AddUpdateSongView(addUpdateSong: AddUpdateSong(currentSong: song))
            }
        }
        .onAppear {
            Task {
                do {
                    try await songData.fetchSongs()
                    
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
}

#Preview {
    SongList()
}
