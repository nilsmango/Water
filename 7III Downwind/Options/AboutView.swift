//
//  AboutView.swift
//  7III Downwind
//
//  Created by Simon Lang on 26.01.2024.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject var downwindManager: DownwindManager

    var body: some View {
        ScrollView() {
            VStack(alignment: .leading, spacing: 10) {
                Text("App Version: \(downwindManager.currentAppVersion) \(downwindManager.currentAppBuild)")
                    .font(.footnote)
                
                Text("What can you do with this app?")
                    .font(.headline)
                Text("Track your water sports sessions from your iPhone or your Apple Watch. All the data will get stored in Health so you will never loose the data.\nWater also imports all the water sport sessions you did save to Health in the past.\nYou can also track a session with your Garmin watch and import it into Water.\nAnd you can edit any session you had. The edits will only get saved in 7III Water.")
                
//                Text("Track yourself and your friends during your outdoor activities. You can also save all the location data collected and analyze it later.\nOriginally, this app was made for downwind runs, but you can track the location of any person or group doing any kind of activity.\nPlease note that the GPS data processing has been optimized for outdoor activities and may not perform well indoors.")
                    .font(.body)
//                    .padding(.bottom)
                
//                VStack(alignment: .leading, spacing: 10) {
//                    Text("Disclaimer:")
//                        .font(.headline)
//                        .padding(.top, 10)
//                    
//                    Text("This app is designed for recreational use and should not be considered a substitute for emergency beacons or other rescue devices. Safety is our top priority, and you should always exercise caution and adhere to maritime safety guidelines while using this app. Please be advised that prolonged usage of this application may result in substantial battery consumption. Therefore, you should be mindful and periodically check the battery level to ensure safety during tracking.")
//                        .font(.body)
//                        .onTapGesture(count: 3, perform: {
//                            downwindManager.developerMode.toggle()
//                        })
//                }
//                .padding([.horizontal, .bottom])
//                .padding(.top, 8)
//                .background {
//                    RoundedRectangle(cornerRadius: 20)
//                        .foregroundStyle(.yellow.opacity(0.8))
//                }
                
                Text("What data do we collect?")
                    .font(.headline)
                    .padding(.top)
                Text("We will save your sessions in Health and your edits and imports in 7III Water. No other data of yours ever gets collected by us or anybody else.\nWe don't collect any data of you.")
                
//                Text("We don't collect any data about you for longer than needed. This is the duration of the run. Then only thing persisting in the database is your username, location and speed, with no other data associated with it other than a random ID. Whenever you exit a run we will delete your location data from the database and remove you from the run. If you are only watching a run we don't collect any location data. When the last person exits a run we remove the run from the database.\n\nWe save your tracked runs on your device only.\n\nIf you want to even remove your username and ID from the database, and delete all your locally saved data, simply navigate to the options menu and tap the button saying: \"Delete All My Data\".")
                    .font(.body)
                    .padding(.bottom)
                
                Text("What else?")
                    .font(.headline)
                
                Text("project7III makes useful things.\nFind us: [project7iii.com](https://project7iii.com)\nSend us suggestions and bugs: hi@project7iii.com")
                    .font(.body)
                    .padding(.bottom)
                
                Text("Licenses")
                    .font(.headline)

                Text("This app uses [Keychain Swift](https://github.com/evgenyneu/keychain-swift):\nCopyright (c) 2015 - 2024 Evgenii Neumerzhitckii\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS ORIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THEAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHERLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.")
                    .font(.body)
                    .padding(.bottom)
                
                Text("This app uses [HC Kalman Filter](https://github.com/nilsmango/HCKalmanFilter):\nCopyright (c) 2017 Hypercubesoft\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.")
                    .font(.body)
                    .padding(.bottom)
                
                    Text("""
                    This app uses [XMLCoder](https://github.com/CoreOffice/XMLCoder):
                    Copyright (c) 2018-2019 Shawn Moore and XMLCoder contributors

                    Permission is hereby granted, free of charge, to any person obtaining a copy
                    of this software and associated documentation files (the "Software"), to deal
                    in the Software without restriction, including without limitation the rights
                    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                    copies of the Software, and to permit persons to whom the Software is
                    furnished to do so, subject to the following conditions:

                    The above copyright notice and this permission notice shall be included in all
                    copies or substantial portions of the Software.

                    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                    SOFTWARE.
                    """)
                    .font(.body)
                    .padding(.bottom)
                
                Spacer(minLength: 0.0)
            }
            .padding()
            .navigationTitle("About")
        }
        .background(.listBackground)
            
    }
}

#Preview {
    NavigationStack {
        AboutView(downwindManager: DownwindManager())
    }
}
