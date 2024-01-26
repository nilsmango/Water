//
//  AboutView.swift
//  7III Downwind
//
//  Created by Simon Lang on 26.01.2024.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView() {
            VStack(alignment: .leading, spacing: 10) {
                Text("What can you do with this app?")
                    .font(.headline)
                
                Text("Start downwind runs, share them with friends, and watch them unfold in real-time. Track speed and location of your whole downwind crew.")
                    .font(.body)
                    .padding(.bottom)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Disclaimer:")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    Text("This app is designed for recreational use and should not be considered a substitute for emergency beacons or other rescue devices. Safety is our top priority, and you should always exercise caution and adhere to maritime safety guidelines while using this app.")
                        .font(.body)
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 8)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.yellow.opacity(0.8))
                    
                }

                Text("What data do we collect?")
                    .font(.headline)
                    .padding(.top)
                
                Text("We don't collect any data about you for longer than needed. This is the duration of the run. Then only thing persisting in the database is your username, with no other data associated with it other than a random ID. Whenever you exit a run we will delete your location data from the database and remove you from the run. If you are only watching a run we don't collect any location data. When the last person exits a run we remove the run from the database. If you want to even remove your username and id from the database simply navigate to the options menu and tap the very last button. As simple as that.")
                    .font(.body)
                    .padding(.bottom)
                
                Text("What else?")
                    .font(.headline)
                    .padding(.top)
                
                
                Text("project7III makes useful things.\nFind us: [project7iii.com](https://project7iii.com)\nWrite to us: dw@project7iii.com")
                    .font(.body)
                    .padding(.bottom)
                     
                     Text("Changelog")
                         .font(.headline)
                         .padding(.top)
                     Text("January 2024: Version 0.1 made with ❤️ by [Nils Mango](https://nilsmango.ch) in Switzerland.")
                    .font(.body)
                    .padding(.bottom)
                     
                Spacer()
            }
            .padding()
        }
        .background {
            Rectangle()
                .ignoresSafeArea()
                .foregroundStyle(.listBackground)
        }
    }
}

#Preview {
    AboutView()
}
