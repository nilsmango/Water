//
//  AddUpdateSong.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import SwiftUI

final class AddUpdateSong: ObservableObject {
    @Published var songTitle = ""
    
    var songID: UUID?
    
    var isUpdating: Bool {
        songID != nil
    }
    
    var buttonTitle: String {
        songID != nil ? "Update Song" : "Add Song"
    }
    
    init() {}
    
    init(currentSong: Song) {
        self.songTitle = currentSong.title
        self.songID = currentSong.id
    }
    
    func addUpdateAction(completion: @escaping () -> Void) {
        Task {
            do {
                if isUpdating {
                    try await updateSong()
                } else {
                    try await addSong()
                }
            } catch {
                print("Error: \(error)")
            }
            completion()
        }
    }
    
    func addSong() async throws {
        let url = try createSongURL()
        
        let song = Song(id: nil, title: songTitle)
        
        try await HTTPClient.shared.sendData(to: url, object: song, httpMethod: HTTPMethods.POST.rawValue)
    }
    
    func updateSong() async throws {
        let url = try createSongURL()
        
        let songToUpdate = Song(id: songID, title: songTitle)
        
        try await HTTPClient.shared.sendData(to: url, object: songToUpdate, httpMethod: HTTPMethods.PUT.rawValue)
    }
    
    
}
