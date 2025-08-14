//
//  WebPreview.swift
//  WebTracker
//
//  Created by Simon Lang on 28.07.2025.
//

import SwiftUI
import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

struct WebPreviewView: View {
    let url: String
    @Binding var cssSelector: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedElement = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if !selectedElement.isEmpty {
                    Group {
                        VStack {
                            Text("Selected Element:")
                            Text(selectedElement)
                                .font(.caption)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button("Use this Selector") {
                                cssSelector = selectedElement
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.yellow.opacity(0.1))
                        .cornerRadius(10)
                        
                    }
                    .padding(6)
                    
                }
                
                WebView(url: url, selectedElement: $selectedElement)
            
            .navigationTitle("Select Element")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
            .toolbar {
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
            
        }
    }
}


struct WebView: PlatformViewRepresentable {
    let url: String
    @Binding var selectedElement: String

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateUIView(_ uiView: WKWebView, context: Context) { updateWebView(uiView, context: context) }
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateNSView(_ nsView: WKWebView, context: Context) { updateWebView(nsView, context: context) }
    #endif

    private func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "elementSelected")
        config.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    private func updateWebView(_ webView: WKWebView, context: Context) {
        if let u = URL(string: url) {
            webView.load(URLRequest(url: u))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebView
        private var storedXPath: String = ""
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // JavaScript to make elements selectable and restore previous selection
            let js = """
            function getXPath(el) {
                if (el.id) {
                    return `//*[@id="${el.id}"]`;
                }
                const parts = [];
                while (el && el.nodeType === Node.ELEMENT_NODE) {
                    let index = 1;
                    let sibling = el.previousSibling;
                    while (sibling) {
                        if (sibling.nodeType === Node.ELEMENT_NODE && sibling.nodeName === el.nodeName) {
                            index++;
                        }
                        sibling = sibling.previousSibling;
                    }
                    parts.unshift(`${el.nodeName.toLowerCase()}[${index}]`);
                    el = el.parentNode;
                }
                return '/' + parts.join('/');
            }

            function getElementsByXPath(xpath) {
                return document.evaluate(xpath, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
            }

            function highlightElement(xpath) {
                // Clear previous highlights
                document.querySelectorAll('.temp-highlight').forEach(el => {
                    el.classList.remove('temp-highlight');
                    el.style.border = '';
                    el.style.backgroundColor = '';
                });

                if (xpath) {
                    const result = getElementsByXPath(xpath);
                    if (result.snapshotLength > 0) {
                        const element = result.snapshotItem(0);
                        element.style.border = '2px solid #007AFF';
                        element.style.backgroundColor = 'rgba(0, 122, 255, 0.1)';
                        element.classList.add('temp-highlight');
                    }
                }
            }

            document.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();

                // Highlight the clicked element
                document.querySelectorAll('.temp-highlight').forEach(el => {
                    el.classList.remove('temp-highlight');
                    el.style.border = '';
                    el.style.backgroundColor = '';
                });

                e.target.style.border = '2px solid #007AFF';
                e.target.style.backgroundColor = 'rgba(0, 122, 255, 0.1)';
                e.target.classList.add('temp-highlight');

                const xpath = getXPath(e.target);

                window.webkit.messageHandlers.elementSelected.postMessage({
                    selector: xpath,
                    text: e.target.textContent.trim().substring(0, 50),
                    tagName: e.target.tagName
                });
            });

            // Restore previous selection if exists
            const storedXPath = '\(storedXPath.replacingOccurrences(of: "'", with: "\\'"))';
            if (storedXPath) {
                highlightElement(storedXPath);
            }
            """
            
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("JavaScript injection error: \(error)")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Failed to load: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Navigation failed: \(error.localizedDescription)")
        }
        
        // WKScriptMessageHandler method
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "elementSelected",
               let data = message.body as? [String: Any],
               let selector = data["selector"] as? String {
                
                // Store the XPath for persistence across page loads
                storedXPath = selector
                
                DispatchQueue.main.async {
                    self.parent.selectedElement = selector
                }
            }
        }
    }
}
