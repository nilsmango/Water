//
//  ReviewRequestView.swift
//  7III Tracker
//
//  Created by Simon Lang on 06.04.2025.
//

import SwiftUI
import StoreKit

struct ReviewRequestView: View {
    @AppStorage("hasRespondedToReview") var hasRespondedToReviewRequest = false
    @State private var showingReviewOptions = false
    
    private let appId = "id6495238780"
    
    var body: some View {
        if !hasRespondedToReviewRequest {
            VStack(spacing: 16) {
                Label("Do you like 7III Water?", systemImage: "pencil.and.list.clipboard")
                
                if !showingReviewOptions {
                    VStack(spacing: 12) {
                        Button {
                            showingReviewOptions = true
                        } label: {
                            Label("Yes", systemImage: "hand.thumbsup")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            openMailtoLink()
                            hasRespondedToReviewRequest = true
                        } label: {
                            Label("No", systemImage: "hand.thumbsdown")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if showingReviewOptions {
                    VStack(spacing: 12) {
                        Button {
                            openAppStoreReview()
                            hasRespondedToReviewRequest = true
                        } label: {
                            Label("Help us out by writing a review", systemImage: "heart.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showingReviewOptions = false
                        } label: {
                            Label("Maybe later", systemImage: "clock.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showingReviewOptions)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background {
                ListBackground()
            }
        }
    }
    
    private func openMailtoLink() {
        let subject = "Feedback for 7III Water"
        let body = "Here's what I don't like about 7III Water:"
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let mailtoString = "mailto:7+water@project7iii.com?subject=\(encodedSubject)&body=\(encodedBody)"
        
        if let mailtoURL = URL(string: mailtoString) {
            UIApplication.shared.open(mailtoURL, options: [:], completionHandler: nil)
        }
    }
    
    private func openAppStoreReview() {
        let urlString = "https://apps.apple.com/app/\(appId)?action=write-review"
        guard let url = URL(string: urlString) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Fallback to requesting review in-app
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ReviewRequestView()
            .padding()
        Spacer()
    }
    
    .background {
        Rectangle()
            .ignoresSafeArea()
            .foregroundStyle(.listBackground)
    }
}
