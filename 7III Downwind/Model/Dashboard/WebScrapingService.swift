//
//  WebScrapingService.swift
//  WebTracker
//
//  Created by Simon Lang on 28.07.2025.
//

import Foundation
import WebKit
import Kanna

// MARK: - Completion State Helper
class CompletionState {
    var hasCompleted = false
}

// MARK: - Web Scraper Service
class WebScrapingService: NSObject, @unchecked Sendable {
    
    private var webView: WKWebView?
    private var completion: ((Result<String, WebScrapingError>) -> Void)?
    
    func fetchElementValue(url: String, xpath: String, maxWaitTime: TimeInterval = 5.0, maxWaitAfterPlaceholder: TimeInterval = 2.7) async throws -> String {
        guard let url = URL(string: url) else {
            throw WebScrapingError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.setupWebView()
                self.completion = { result in
                    continuation.resume(with: result)
                }
                
                let request = URLRequest(url: url)
                self.webView?.load(request)
                
                // Start checking immediately, no initial delay
                self.waitForXPathElementAndExtract(xpath: xpath, maxWaitTime: maxWaitTime, startTime: Date(), maxWaitAfterPlaceholder: maxWaitAfterPlaceholder)
            }
        }
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
    }
    
    private func extractContent(xpath: String) {
        let jsCode = """
        document.documentElement.outerHTML;
        """
        
        webView?.evaluateJavaScript(jsCode) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.completion?(.failure(.javascriptError(error)))
                return
            }
            
            guard let html = result as? String else {
                self.completion?(.failure(.parsingError(NSError(domain: "HTMLExtraction", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract HTML"]))))
                return
            }
            
            if let value = self.extractTextFromHTML(html: html, xpath: xpath) {
                self.completion?(.success(value))
            } else {
                self.completion?(.failure(.elementNotFound))
            }
            
            // Clean up
            self.webView = nil
            self.completion = nil
        }
    }
    
    private func extractTextFromHTML(html: String, xpath: String) -> String? {
        do {
            let doc = try HTML(html: html, encoding: .utf8)
            if let element = doc.at_xpath(xpath) {
                let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                return text?.isEmpty == false ? text : nil
            } else {
                print("No element found for xpath: \(xpath)")
                return nil
            }
        } catch {
            print("XPath parsing error: \(error)")
            return nil
        }
    }
}

// MARK: - WKNavigationDelegate
extension WebScrapingService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page navigation finished")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(.networkError(error)))
        self.webView = nil
        self.completion = nil
    }
}

// MARK: - Fast XPath Checking with Aggressive Polling
extension WebScrapingService {
    // If we found a placeholder value, give it 2.7s extra to update
    private func waitForXPathElementAndExtract(xpath: String, maxWaitTime: TimeInterval, startTime: Date, foundPlaceholderAt: Date? = nil, maxWaitAfterPlaceholder: TimeInterval = 2.7) {
        let elapsed = Date().timeIntervalSince(startTime)
        
        
        let effectiveMaxWaitTime = foundPlaceholderAt != nil ?
        min(maxWaitTime, Date().timeIntervalSince(foundPlaceholderAt!) + 2.0) : maxWaitTime
        
        if elapsed >= effectiveMaxWaitTime {
            print("Timeout waiting for element at xpath: \(xpath) after \(elapsed) seconds")
            extractContent(xpath: xpath)
            return
        }
        
        // Create JavaScript to check if xpath element exists and has content
        let jsCondition = """
        (function() {
            try {
                var result = document.evaluate('\(xpath)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                var element = result.singleNodeValue;
                var hasContent = element !== null;
                var textContent = element ? (element.textContent || element.innerText || '').trim() : '';
                var isPlaceholder = /^-+\\s*\\w{1,10}$/.test(textContent) || textContent === '' || textContent === '-' || textContent === '--' || textContent === '---';
                return {
                    found: hasContent,
                    hasText: textContent.length > 0,
                    textLength: textContent.length,
                    textContent: textContent,
                    isPlaceholder: isPlaceholder,
                    element: element ? element.tagName : null
                };
            } catch(e) {
                return {
                    found: false,
                    hasText: false,
                    textLength: 0,
                    textContent: '',
                    isPlaceholder: false,
                    element: null,
                    error: e.toString()
                };
            }
        })();
        """
        
        webView?.evaluateJavaScript(jsCondition) { result, error in
            let currentElapsed = Date().timeIntervalSince(startTime)
            
            if let error = error {
                print("XPath condition check error at \(currentElapsed)s: \(error)")
                // Continue polling even on JS error
                let pollingInterval = self.calculatePollingInterval(elapsed: currentElapsed, maxWaitTime: maxWaitTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + pollingInterval) {
                    self.waitForXPathElementAndExtract(xpath: xpath, maxWaitTime: maxWaitTime, startTime: startTime, foundPlaceholderAt: foundPlaceholderAt)
                }
                return
            }
            
            if let resultDict = result as? [String: Any],
               let found = resultDict["found"] as? Bool {
                
                let textContent = resultDict["textContent"] as? String ?? ""
                let isPlaceholder = resultDict["isPlaceholder"] as? Bool ?? false
                let elementType = resultDict["element"] as? String ?? "unknown"
                
                print("XPath check at \(String(format: "%.2f", currentElapsed))s - Found: \(found), Text: '\(textContent)', IsPlaceholder: \(isPlaceholder), Element: \(elementType)")
                
                if found {
                    if isPlaceholder {
                        // Found element but it has placeholder content (empty, -, --, ---)
                        let newFoundPlaceholderAt = foundPlaceholderAt ?? Date()
                        let placeholderElapsed = Date().timeIntervalSince(newFoundPlaceholderAt)
                        
                        if placeholderElapsed < maxWaitAfterPlaceholder {
                            print("Found placeholder value '\(textContent)', waiting for JS update (waited \(String(format: "%.2f", placeholderElapsed))s)")
                            // Continue polling for JS updates
                            let pollingInterval = self.calculatePollingInterval(elapsed: currentElapsed, maxWaitTime: maxWaitTime)
                            DispatchQueue.main.asyncAfter(deadline: .now() + pollingInterval) {
                                self.waitForXPathElementAndExtract(xpath: xpath, maxWaitTime: maxWaitTime, startTime: startTime, foundPlaceholderAt: newFoundPlaceholderAt)
                            }
                        } else {
                            print("Placeholder value timeout after \(String(format: "%.2f", placeholderElapsed))s, extracting current content")
                            self.extractContent(xpath: xpath)
                        }
                    } else {
                        // Found element with real content
                        print("Element with real content found at xpath: \(xpath) after \(String(format: "%.2f", currentElapsed)) seconds")
                        self.extractContent(xpath: xpath)
                    }
                } else {
                    // Element not found yet, continue polling
                    let pollingInterval = self.calculatePollingInterval(elapsed: currentElapsed, maxWaitTime: maxWaitTime)
                    DispatchQueue.main.asyncAfter(deadline: .now() + pollingInterval) {
                        self.waitForXPathElementAndExtract(xpath: xpath, maxWaitTime: maxWaitTime, startTime: startTime, foundPlaceholderAt: foundPlaceholderAt)
                    }
                }
            } else {
                print("Unexpected result format from XPath check: \(result ?? "nil")")
                // Continue polling with fallback
                let pollingInterval = self.calculatePollingInterval(elapsed: currentElapsed, maxWaitTime: maxWaitTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + pollingInterval) {
                    self.waitForXPathElementAndExtract(xpath: xpath, maxWaitTime: maxWaitTime, startTime: startTime, foundPlaceholderAt: foundPlaceholderAt)
                }
            }
        }
    }
    
    private func calculatePollingInterval(elapsed: TimeInterval, maxWaitTime: TimeInterval) -> TimeInterval {
        // Start with very frequent checks, then slow down
        if elapsed < 1.0 {
            return 0.05  // Check every 50ms for first second
        } else if elapsed < 3.0 {
            return 0.05   // Every 50ms for next 2 seconds
        } else if elapsed < 5.0 {
            return 0.1  // Every 100ms for next 4 seconds
        } else {
            return 0.25   // Every 250ms after that
        }
    }
}

enum WebScrapingError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(Error)
    case elementNotFound
    case javascriptError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Parsing error: \(error.localizedDescription)"
        case .elementNotFound:
            return "Element not found with the given selector"
        case .javascriptError(let error):
            return "JavaScript execution error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Fast Batch Web Scraping Extension
extension WebScrapingService {
    
    func processElementsForURL(url: String, elements: [TrackedElement], maxWaitTime: TimeInterval = 5.0, maxWaitAfterPlaceholder: TimeInterval = 2.7) async -> [TrackedElement] {
        guard let url = URL(string: url) else {
            return elements.map { element in
                var updatedElement = element
                updatedElement.lastError = "Invalid URL"
                updatedElement.lastUpdated = Date()
                return updatedElement
            }
        }
        
        // Process each element individually to wait for specific XPaths
        var results: [TrackedElement] = []
        
        for element in elements {
            do {
                let value = try await fetchElementValue(url: url.absoluteString, xpath: element.xpath, maxWaitTime: maxWaitTime, maxWaitAfterPlaceholder: maxWaitAfterPlaceholder)
                var updatedElement = element
                updatedElement.lastValue = value
                updatedElement.lastError = nil
                updatedElement.lastUpdated = Date()
                results.append(updatedElement)
            } catch {
                var updatedElement = element
                updatedElement.lastError = error.localizedDescription
                updatedElement.lastUpdated = Date()
                results.append(updatedElement)
            }
        }
        
        return results
    }
    
    private func loadWebpageFast(url: URL, maxWaitTime: TimeInterval = 15.0) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.setupWebView()
                
                // Use a class to hold the completion state
                let completionState = CompletionState()
                let completionHandler: (Result<String, WebScrapingError>) -> Void = { result in
                    guard !completionState.hasCompleted else { return }
                    completionState.hasCompleted = true
                    continuation.resume(with: result)
                }
                
                self.completion = completionHandler
                
                let request = URLRequest(url: url)
                self.webView?.load(request)
                
                // Start checking immediately - no initial delay!
                let startTime = Date()
                self.pollForPageReady(startTime: startTime, maxWaitTime: maxWaitTime, completionState: completionState)
                
                // Timeout handler
                DispatchQueue.main.asyncAfter(deadline: .now() + maxWaitTime) {
                    guard !completionState.hasCompleted else { return }
                    completionState.hasCompleted = true
                    continuation.resume(throwing: WebScrapingError.networkError(
                        NSError(domain: "WebScrapingTimeout", code: 0,
                               userInfo: [NSLocalizedDescriptionKey: "Page load timeout after \(maxWaitTime) seconds"])
                    ))
                    self.webView = nil
                    self.completion = nil
                }
            }
        }
    }
    
    private func pollForPageReady(startTime: Date, maxWaitTime: TimeInterval, completionState: CompletionState) {
        let elapsed = Date().timeIntervalSince(startTime)
        
        if elapsed >= maxWaitTime || completionState.hasCompleted {
            return
        }
        
        // Check if document is ready
        let jsCode = """
        (function() {
            return {
                readyState: document.readyState,
                hasBody: document.body !== null,
                bodyChildren: document.body ? document.body.children.length : 0
            };
        })();
        """
        
        webView?.evaluateJavaScript(jsCode) { result, error in
            guard !completionState.hasCompleted else { return }
            
            if let error = error {
                print("Page ready check error: \(error)")
                // Continue polling even on error
                let pollingInterval = self.calculatePollingInterval(elapsed: elapsed, maxWaitTime: maxWaitTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + pollingInterval) {
                    self.pollForPageReady(startTime: startTime, maxWaitTime: maxWaitTime, completionState: completionState)
                }
                return
            }
            
            // Try to extract HTML as soon as we can, don't wait for "complete" state
            if let resultDict = result as? [String: Any],
               let readyState = resultDict["readyState"] as? String,
               let hasBody = resultDict["hasBody"] as? Bool,
               hasBody && (readyState == "interactive" || readyState == "complete") {
                
                print("Page ready (readyState: \(readyState)), extracting HTML")
                self.extractPageHTML()
            } else {
                // Continue polling with dynamic interval
                let pollingInterval = self.calculatePollingInterval(elapsed: elapsed, maxWaitTime: maxWaitTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + pollingInterval) {
                    self.pollForPageReady(startTime: startTime, maxWaitTime: maxWaitTime, completionState: completionState)
                }
            }
        }
    }
    
    private func extractPageHTML() {
        let jsCode = """
        document.documentElement.outerHTML;
        """
        
        webView?.evaluateJavaScript(jsCode) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.completion?(.failure(.javascriptError(error)))
                return
            }
            
            guard let html = result as? String else {
                self.completion?(.failure(.parsingError(
                    NSError(domain: "HTMLExtraction", code: 0,
                           userInfo: [NSLocalizedDescriptionKey: "Failed to extract HTML"])
                )))
                return
            }
            
            self.completion?(.success(html))
            
            // Clean up
            self.webView = nil
            self.completion = nil
        }
    }
}
