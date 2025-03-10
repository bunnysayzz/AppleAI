@preconcurrency
import SwiftUI
@preconcurrency import WebKit

// A coordinator class to handle WKWebView callbacks
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var parent: AIWebView
    
    init(_ parent: AIWebView) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.isLoading = false
        
        // Make the webView the first responder when navigation completes
        DispatchQueue.main.async {
            if let window = webView.window {
                window.makeFirstResponder(webView)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
    }
    
    // WKUIDelegate methods for handling UI interactions
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
}

struct AIWebView: NSViewRepresentable {
    let url: URL
    let service: AIService
    @Binding var isLoading: Bool
    
    // For SwiftUI previews
    init(url: URL, service: AIService) {
        self.url = url
        self.service = service
        self._isLoading = .constant(true)
    }
    
    // For actual use
    init(url: URL, service: AIService, isLoading: Binding<Bool>) {
        self.url = url
        self.service = service
        self._isLoading = isLoading
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        // Create a configuration for the webview
        let configuration = WKWebViewConfiguration()
        
        // Set preferences for keyboard input
        let preferences = WKPreferences()
        
        // Using the newer API for JavaScript
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        
        configuration.preferences = preferences
        
        // Create process pool and website data store
        let processPool = WKProcessPool()
        configuration.processPool = processPool
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Set user agent
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        // Create the web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        // Set delegates
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Configure to receive and handle keyboard events
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.wantsLayer = true
        
        // We can't set acceptsFirstResponder directly as it's a get-only property
        // Instead, ensure the webView can be focused through other means
        
        // Load the URL
        webView.load(URLRequest(url: url))
        
        // Track last usage time
        UserDefaults.standard.set(Date(), forKey: "lastUsed_\(service.name)")
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Ensure the webView is the first responder when it becomes visible
        DispatchQueue.main.async {
            if let window = nsView.window, !nsView.isHidden {
                window.makeFirstResponder(nsView)
            }
        }
    }
}

// Add a SwiftUI representable NSViewController to ensure proper focus handling
class WebViewHostingController: NSViewController {
    var webView: WKWebView
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = webView
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure the webView becomes first responder when the view appears
        DispatchQueue.main.async { [weak self] in
            if let window = self?.view.window {
                window.makeFirstResponder(self?.webView)
            }
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

struct WebViewWindow: View {
    let service: AIService
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            HStack {
                HStack(spacing: 8) {
                    Image(service.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(service.name)
                        .font(.headline)
                }
                .foregroundColor(service.color)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            AIWebView(url: service.url, service: service, isLoading: $isLoading)
                .id(service.id) // Force recreation when service changes
                .onAppear {
                    // Short delay to ensure view is fully loaded before attempting to set focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let window = NSApplication.shared.keyWindow {
                            // Attempt to make the webView first responder through the window hierarchy
                            for subview in window.contentView?.subviews ?? [] {
                                if NSStringFromClass(type(of: subview)).contains("WKWebView") {
                                    window.makeFirstResponder(subview)
                                    return
                                }
                            }
                        }
                    }
                }
        }
    }
} 