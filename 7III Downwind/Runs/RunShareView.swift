//
//  RunShareView.swift
//  7III Downwind
//
//  Created by Simon Lang on 16.01.2024.
//

import SwiftUI

struct RunShareView: View {
    var runName: String
    var body: some View {
        VStack {
            
            Text("Instructions for Joining A Run")
                .fontWeight(.bold)
                .padding(.bottom, 1.0)
            
            Text("""
                    1. Open 7III Downwind
                    2. Tap \"Join A Run\"
                    3. Enter name:
                """)
            .padding(.bottom, 2.0)
            
            Text(runName)
                .textSelection(.enabled)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .padding(6)
                .background {
                    Capsule()
                        .foregroundStyle(.dwGray)
                }
            Text("For copying/sharing simply long press the name.")
                .font(.caption)
            
            
        }
        
    }
}

#Preview {
    RunShareView(runName: "Run 01")
}
