//
//  SongData.swift
//  7III Downwind
//
//  Created by Simon Lang on 22.12.23.
//

import SwiftUI

class SongData: ObservableObject {
    @Published var songs = [Song]()
    
    func fetchSongs() async throws {
        let url = try createSongURL()
        
        let songResponse: [Song] = try await HTTPClient.shared.fetch(url: url)
        
        DispatchQueue.main.async {
            self.songs = songResponse
        }
    }
    
    func delete(at offsets: IndexSet) {
        offsets.forEach { i in
            guard let songID = songs[i].id else {
                return
            }
            
            guard let url = URL(string: Constants.baseURL + Endpoints.songs + "/\(songID)") else {
                return
            }
            
            Task {
                do {
                    try await HTTPClient.shared.delete(at: songID, url: url)
                } catch {
                    print("Error \(error)")
                }
            }
        }
        
        songs.remove(atOffsets: offsets)
    }
    
}
