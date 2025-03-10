import SwiftUI
import WebKit

class WebViewCache: ObservableObject {
    static let shared = WebViewCache()
    
    @Published private var webViews: [String: WKWebView] = [:]
    @Published private var loadingStates: [String: Bool] = [:]
    private var coordinators: [String: WebViewCoordinator] = [:]
    
    private init() {
        // Initialize web views for all services
        preloadWebViews()
    }
    
    private func preloadWebViews() {
        for service in aiServices {
            createWebView(for: service)
        }
    }
    
    private func createWebView(for service: AIService) {
        let configuration = WKWebViewConfiguration()
        let preferences = WKPreferences()
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        configuration.preferences = preferences
        configuration.processPool = WKProcessPool()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        let coordinator = WebViewCoordinator(AIWebView(url: service.url, service: service))
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.wantsLayer = true
        
        // Load the URL
        webView.load(URLRequest(url: service.url))
        
        // Store the web view and its coordinator
        webViews[service.id.uuidString] = webView
        coordinators[service.id.uuidString] = coordinator
        loadingStates[service.id.uuidString] = true
        
        // Track last usage time
        UserDefaults.standard.set(Date(), forKey: "lastUsed_\(service.name)")
    }
    
    func webView(for service: AIService) -> WKWebView {
        if let existingWebView = webViews[service.id.uuidString] {
            return existingWebView
        }
        
        // If web view doesn't exist (shouldn't happen normally), create it
        createWebView(for: service)
        return webViews[service.id.uuidString]!
    }
    
    func isLoading(for service: AIService) -> Bool {
        return loadingStates[service.id.uuidString] ?? false
    }
    
    func setLoading(_ isLoading: Bool, for service: AIService) {
        loadingStates[service.id.uuidString] = isLoading
    }
    
    func refreshWebView(for service: AIService) {
        guard let webView = webViews[service.id.uuidString] else { return }
        webView.reload()
    }
    
    func clearCache() {
        // Clear all web views and their cache
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [weak self] in
            self?.webViews.removeAll()
            self?.coordinators.removeAll()
            self?.loadingStates.removeAll()
            self?.preloadWebViews()
        }
    }
} 