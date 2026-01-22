//
//  SpotDetailView.swift
//  7III Downwind
//
//  Created by Simon Lang on 21.01.2026.
//

import SwiftUI
import SafariServices
import WebKit

#if os(iOS)

struct SpotDetailView: View {
    let spot: Spot
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: Video?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    headerSection
                    
                    if !spot.infos.isEmpty {
                        infosSection
                    }
                    
                    if let videos = spot.videos, !videos.isEmpty {
                        videosSection
                    }
                    
                    if let distance = spot.distance {
                        distanceSection(distance: distance)
                    }
                }
                .padding()
            }
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(item: $selectedVideo) { video in
            VideoPlayerView(video: video)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: spot.kind.iconName)
                    .font(.title)
                    .foregroundStyle(spot.pending == true ? Color.gray : Color.accentColor)

                VStack(alignment: .leading) {
                    Text(spot.kind.label)
                        .font(.headline)

                    Text([spot.country, spot.usState].compactMap { $0 }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
    }
    
    private var infosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)
            
            ForEach(spot.infos, id: \.id) { info in
                infoRow(for: info)
            }
        }
    }
    
    private func infoRow(for info: SpotInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let userUrl = info.userUrl, let url = URL(string: userUrl) {
                    Link(info.userName, destination: url)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(info.userName)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                
                Spacer()
                
                if let date = formatDate(info.date) {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let attributedText = attributedText(info.text) {
                Text(attributedText)
                    .font(.body)
            } else {
                Text(info.text)
                    .font(.body)
            }
            
            if let votes = info.votes {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                    Text("\(votes)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.uiGray)
        }
    }
    
    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Videos")
                .font(.headline)
            
            if let videos = spot.videos {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(videos) { video in
                            Button {
                                selectedVideo = video
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 160, height: 90)
                                        .overlay {
                                            Image(systemName: "play.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.red)
                                        }
                                    
                                    HStack {
                                        Text(video.kind.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func distanceSection(distance: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distance")
                .font(.headline)
            
            HStack {
                Image(systemName: "ruler")
                Text("\(distance, specifier: "%.1f") km")
                    .font(.body)
            }
            .foregroundStyle(.secondary)
        }
    }
    
    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        
        return displayFormatter.string(from: date)
    }
    
    private func attributedText(_ text: String) -> AttributedString? {
        var attributedString = AttributedString(text)
        
        // Example: detecting URLs with NSDataDetector or regex
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches ?? [] {
            if let urlString = match.url?.absoluteString,
               let range = Range(match.range, in: attributedString) {  // Convert here!
                attributedString[range].link = URL(string: urlString)
                attributedString[range].foregroundColor = .accentColor
                attributedString[range].font = .body.bold()
            }
        }
        
        return attributedString
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let video: Video
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        
        if let url = URL(string: video.url) {
            if video.kind == .youtube {
                let player = YouTubePlayerViewController(videoURL: url)
                vc.addChild(player)
                vc.view.addSubview(player.view)
                player.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    player.view.topAnchor.constraint(equalTo: vc.view.topAnchor),
                    player.view.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                    player.view.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                    player.view.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
                ])
                player.didMove(toParent: vc)
            } else {
                let safari = SFSafariViewController(url: url)
                safari.preferredBarTintColor = .systemBackground
                safari.preferredControlTintColor = .blue
                vc.present(safari, animated: true)
            }
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class YouTubePlayerViewController: UIViewController {
    private var webView: WKWebView?
    let videoURL: URL
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = WKWebView()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        self.webView = webView
        
        loadVideo()
    }
    
    private func loadVideo() {
        var videoID = ""
        if videoURL.absoluteString.contains("youtube.com") || videoURL.absoluteString.contains("youtu.be") {
            if let range = videoURL.absoluteString.range(of: "(?<=v=|/videos/|/embed/|/v/|/watch\\?v=|youtu.be/)[^#&?\\n]*", options: .regularExpression) {
                videoID = String(videoURL.absoluteString[range])
            }
        }
        
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
        body {
            margin: 0;
            padding: 0;
            background: black;
        }
        iframe {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
        }
        </style>
        </head>
        <body>
        <iframe src="https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=1" 
                frameborder="0" 
                allow="autoplay; encrypted-media" 
                allowfullscreen>
        </iframe>
        </body>
        </html>
        """
        
        webView?.loadHTMLString(embedHTML, baseURL: nil)
    }
}

extension YouTubePlayerViewController: WKNavigationDelegate {}

#Preview {
    SpotDetailView(spot: Spot(
        id: "test",
        name: "Test Spot",
        country: "CH",
        usState: nil,
        kind: .windSpot,
        distance: nil,
        pending: false,
        locations: [Spot.Location(lat: 47.0, lng: 8.0)],
        infos: [],
        videos: nil
    ))
}

#endif
