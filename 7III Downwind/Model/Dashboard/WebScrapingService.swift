//
//  WebScrapingService.swift
//  WebTracker
//
//  Created by Simon Lang on 28.07.2025.
//

import Foundation
import WebKit

/// Serializes work per host while still allowing unrelated hosts to refresh in parallel.
/// One caller can extract many values from one page without paying this delay again.
private actor WebHostRequestScheduler {
    static let shared = WebHostRequestScheduler()

    private var activeHosts: Set<String> = []
    private var nextAllowedStart: [String: Date] = [:]
    private let minimumDelayBetweenLoads: TimeInterval = 0.8

    func acquire(for url: URL) async -> String {
        let hostKey = url.host?.lowercased() ?? url.absoluteString

        while activeHosts.contains(hostKey) {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Reserve the host before sleeping so another waiter cannot pass us while
        // this actor is re-entrant during the delay.
        activeHosts.insert(hostKey)

        if let nextStart = nextAllowedStart[hostKey] {
            let delay = nextStart.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        return hostKey
    }

    func release(_ hostKey: String, retryAfter: TimeInterval? = nil) {
        activeHosts.remove(hostKey)
        nextAllowedStart[hostKey] = Date().addingTimeInterval(
            max(minimumDelayBetweenLoads, retryAfter ?? 0)
        )
    }
}

// MARK: - Web Scraper Service
final class WebScrapingService: NSObject, @unchecked Sendable {
    private typealias XPathResults = [String: Result<String, WebScrapingError>]

    private var webView: WKWebView?
    private var activeOperationID: UUID?
    private var activeCompletion: ((Result<XPathResults, WebScrapingError>) -> Void)?
    private var placeholderStartedAt: [String: Date] = [:]
    private var latestPlaceholderText: [String: String] = [:]
    private var collectedValues: [String: String] = [:]

    static func normalizedPageURLString(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        components.scheme = scheme
        components.host = host.lowercased()
        components.fragment = nil
        if (scheme == "https" && components.port == 443) ||
            (scheme == "http" && components.port == 80) {
            components.port = nil
        }
        return components.url?.absoluteString
    }

    func fetchElementValue(
        url rawURL: String,
        xpath: String,
        maxWaitTime: TimeInterval = 5.0,
        maxWaitAfterPlaceholder: TimeInterval = 2.7
    ) async throws -> String {
        guard let normalizedURL = Self.normalizedPageURLString(rawURL),
              let url = URL(string: normalizedURL),
              !xpath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebScrapingError.invalidURL
        }

        let results = try await fetchWithPoliteRetry(
            url: url,
            xpaths: [xpath],
            maxWaitTime: maxWaitTime,
            maxWaitAfterPlaceholder: maxWaitAfterPlaceholder
        )
        guard let result = results[xpath] else {
            throw WebScrapingError.elementNotFound
        }
        return try result.get()
    }

    func processElementsForURL(
        url rawURL: String,
        elements: [TrackedElement],
        maxWaitTime: TimeInterval = 5.0,
        maxWaitAfterPlaceholder: TimeInterval = 2.7
    ) async -> [TrackedElement] {
        guard let normalizedURL = Self.normalizedPageURLString(rawURL),
              let url = URL(string: normalizedURL) else {
            return updating(elements, with: .failure(.invalidURL))
        }

        do {
            // All selectors for this exact page share one WKWebView navigation.
            let results = try await fetchWithPoliteRetry(
                url: url,
                xpaths: elements.map(\.xpath),
                maxWaitTime: maxWaitTime,
                maxWaitAfterPlaceholder: maxWaitAfterPlaceholder
            )

            return elements.map { element in
                var updated = element
                switch results[element.xpath] ?? .failure(.elementNotFound) {
                case .success(let value):
                    updated.lastValue = value
                    updated.lastError = nil
                case .failure(let error):
                    updated.lastError = error.localizedDescription
                }
                updated.lastUpdated = Date()
                return updated
            }
        } catch let error as WebScrapingError {
            return updating(elements, with: .failure(error))
        } catch {
            return updating(elements, with: .failure(.networkError(error)))
        }
    }

    private func updating(
        _ elements: [TrackedElement],
        with result: Result<String, WebScrapingError>
    ) -> [TrackedElement] {
        elements.map { element in
            var updated = element
            switch result {
            case .success(let value):
                updated.lastValue = value
                updated.lastError = nil
            case .failure(let error):
                updated.lastError = error.localizedDescription
            }
            updated.lastUpdated = Date()
            return updated
        }
    }

    private func fetchWithPoliteRetry(
        url: URL,
        xpaths: [String],
        maxWaitTime: TimeInterval,
        maxWaitAfterPlaceholder: TimeInterval
    ) async throws -> XPathResults {
        let scheduler = WebHostRequestScheduler.shared
        var lastError: WebScrapingError?

        for attempt in 0..<2 {
            let hostKey = await scheduler.acquire(for: url)
            do {
                let results = try await loadAndExtract(
                    url: url,
                    xpaths: xpaths,
                    maxWaitTime: maxWaitTime,
                    maxWaitAfterPlaceholder: maxWaitAfterPlaceholder
                )
                await scheduler.release(hostKey)
                return results
            } catch let error as WebScrapingError {
                lastError = error
                await scheduler.release(hostKey, retryAfter: error.retryAfter)
                if attempt == 1 || !error.isRetryable {
                    throw error
                }
            } catch {
                let wrapped = WebScrapingError.networkError(error)
                lastError = wrapped
                await scheduler.release(hostKey)
                if attempt == 1 {
                    throw wrapped
                }
            }
        }

        throw lastError ?? .elementNotFound
    }

    private func loadAndExtract(
        url: URL,
        xpaths: [String],
        maxWaitTime: TimeInterval,
        maxWaitAfterPlaceholder: TimeInterval
    ) async throws -> XPathResults {
        let uniqueXPaths = Array(Set(xpaths.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })).sorted()
        guard !uniqueXPaths.isEmpty else { throw WebScrapingError.elementNotFound }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let operationID = UUID()
                self.activeOperationID = operationID
                self.placeholderStartedAt = [:]
                self.latestPlaceholderText = [:]
                self.collectedValues = [:]
                self.activeCompletion = { result in
                    continuation.resume(with: result)
                }

                self.setupWebView()
                var request = URLRequest(
                    url: url,
                    cachePolicy: .useProtocolCachePolicy,
                    timeoutInterval: max(maxWaitTime + maxWaitAfterPlaceholder + 5, 15)
                )
                request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
                self.webView?.load(request)
                self.poll(
                    operationID: operationID,
                    xpaths: uniqueXPaths,
                    startedAt: Date(),
                    maxWaitTime: max(0.5, maxWaitTime),
                    maxWaitAfterPlaceholder: max(0, maxWaitAfterPlaceholder)
                )
            }
        }
    }

    private func setupWebView() {
        webView?.stopLoading()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = "7III-Tracker"
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
    }

    private func poll(
        operationID: UUID,
        xpaths: [String],
        startedAt: Date,
        maxWaitTime: TimeInterval,
        maxWaitAfterPlaceholder: TimeInterval
    ) {
        guard activeOperationID == operationID else { return }

        let unresolved = xpaths.filter { collectedValues[$0] == nil }
        if unresolved.isEmpty {
            finish(operationID: operationID, result: .success(makeResults(for: xpaths)))
            return
        }

        let now = Date()
        let overallDeadline = startedAt.addingTimeInterval(maxWaitTime)
        let expired = unresolved.filter { xpath in
            if let placeholderStart = placeholderStartedAt[xpath] {
                return now >= placeholderStart.addingTimeInterval(maxWaitAfterPlaceholder)
            }
            return now >= overallDeadline
        }

        if !expired.isEmpty {
            for xpath in expired {
                if let placeholder = latestPlaceholderText[xpath], !placeholder.isEmpty {
                    collectedValues[xpath] = placeholder
                }
            }
            if xpaths.allSatisfy({ collectedValues[$0] != nil || expired.contains($0) }) {
                finish(operationID: operationID, result: .success(makeResults(for: xpaths)))
                return
            }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: unresolved),
              let json = String(data: jsonData, encoding: .utf8) else {
            finish(operationID: operationID, result: .failure(.elementNotFound))
            return
        }

        let script = """
        (function(xpaths) {
            return xpaths.map(function(xpath) {
                try {
                    const match = document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
                    const text = match ? (match.textContent || match.innerText || '').trim() : '';
                    const placeholder = text === '' || /^-+$/.test(text) || /^-+\\s*\\w{1,10}$/.test(text);
                    return { xpath: xpath, found: match !== null, text: text, placeholder: placeholder };
                } catch (error) {
                    return { xpath: xpath, found: false, text: '', placeholder: false };
                }
            });
        })(\(json));
        """

        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self, self.activeOperationID == operationID else { return }
            if let rows = result as? [[String: Any]] {
                for row in rows {
                    guard let xpath = row["xpath"] as? String,
                          let found = row["found"] as? Bool,
                          found else { continue }
                    let text = row["text"] as? String ?? ""
                    let isPlaceholder = row["placeholder"] as? Bool ?? false
                    if isPlaceholder {
                        self.placeholderStartedAt[xpath] = self.placeholderStartedAt[xpath] ?? Date()
                        self.latestPlaceholderText[xpath] = text
                    } else {
                        self.collectedValues[xpath] = text
                    }
                }
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let interval: TimeInterval = elapsed < 1 ? 0.1 : (elapsed < 3 ? 0.2 : 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                self.poll(
                    operationID: operationID,
                    xpaths: xpaths,
                    startedAt: startedAt,
                    maxWaitTime: maxWaitTime,
                    maxWaitAfterPlaceholder: maxWaitAfterPlaceholder
                )
            }
        }
    }

    private func makeResults(for xpaths: [String]) -> XPathResults {
        Dictionary(uniqueKeysWithValues: xpaths.map { xpath in
            if let value = collectedValues[xpath], !value.isEmpty {
                return (xpath, .success(value))
            }
            return (xpath, .failure(.elementNotFound))
        })
    }

    private func finish(operationID: UUID, result: Result<XPathResults, WebScrapingError>) {
        guard activeOperationID == operationID else { return }
        let completion = activeCompletion
        activeCompletion = nil
        activeOperationID = nil
        placeholderStartedAt = [:]
        latestPlaceholderText = [:]
        collectedValues = [:]
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        completion?(result)
    }
}

// MARK: - WKNavigationDelegate
extension WebScrapingService: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard navigationResponse.isForMainFrame,
              let response = navigationResponse.response as? HTTPURLResponse,
              !(200...399).contains(response.statusCode),
              let operationID = activeOperationID else {
            decisionHandler(.allow)
            return
        }

        let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
        decisionHandler(.cancel)
        finish(
            operationID: operationID,
            result: .failure(.httpError(statusCode: response.statusCode, retryAfter: retryAfter))
        )
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failActiveOperation(with: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        failActiveOperation(with: error)
    }

    private func failActiveOperation(with error: Error) {
        guard let operationID = activeOperationID else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        finish(operationID: operationID, result: .failure(.networkError(error)))
    }
}

enum WebScrapingError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case elementNotFound
    case httpError(statusCode: Int, retryAfter: TimeInterval?)

    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500
        case .invalidURL, .elementNotFound:
            return false
        }
    }

    var retryAfter: TimeInterval? {
        if case .httpError(_, let retryAfter) = self { return retryAfter }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid HTTP or HTTPS URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .elementNotFound:
            return "Element not found with the given selector"
        case .httpError(let statusCode, let retryAfter):
            if statusCode == 429, let retryAfter {
                return "The website asked us to slow down. Try again in \(Int(retryAfter.rounded(.up))) seconds."
            }
            if statusCode == 429 {
                return "The website asked us to slow down. Please try again later."
            }
            return "The website returned HTTP \(statusCode)"
        }
    }
}
