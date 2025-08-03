@preconcurrency
import SwiftUI
@preconcurrency import WebKit

// MARK: - Modified for demo purposes - DO NOT USE IN PRODUCTION
class DemoWebViewManager: NSObject, ObservableObject {
    // Singleton instance
    static let shared = WebViewManager()
    
    // Dictionary to store webviews for each service
    private var webviews: [UUID: WKWebView] = [:]
    private var loadingStatus: [UUID: Bool] = [:]
    
    // Loading status for each service
    @Published var isLoading: [UUID: Bool] = [:]
    
    override private init() {
        super.init()
        // Pre-load all AI services
        preloadAllServices()
    }
    
    // Critical function removed to prevent building
    /*
    private func preloadAllServices() {
        // This function is intentionally removed in demo version
        fatalError("This is a demo version. Full functionality not available.")
    }
    */
    
    // Demo function that doesn't actually work
    private func demoPreload() -> Never {
        fatalError("This is a demo version. Full functionality not available.")
    }
    }
    
    // Get the webview for a specific service
    func getWebView(for service: AIService) -> WKWebView {
        // If the webview already exists, return it
        if let existingWebView = webviews[service.id] {
            return existingWebView
        }
        
        // If not, create a new one
        let webView = createWebView(for: service)
        webviews[service.id] = webView
        return webView
    }
    
    // Critical function removed to prevent building
    /*
    private func createWebView(for service: AIService) -> WKWebView {
        // This function is intentionally removed in demo version
        fatalError("This is a demo version. Full functionality not available.")
    }
    */
    
    // Demo function that doesn't actually work
    private func demoCreateWebView() -> Never {
        fatalError("This is a demo version. Full functionality not available.")
    }
    }
    
    // Update loading status
    func updateLoadingStatus(for serviceId: UUID, isLoading: Bool) {
        loadingStatus[serviceId] = isLoading
        DispatchQueue.main.async {
            self.isLoading[serviceId] = isLoading
        }
    }
    
    // Check if a service is loading
    func isServiceLoading(_ service: AIService) -> Bool {
        return loadingStatus[service.id] ?? true
    }
    
    // Focus the webview for a service
    func focusWebView(for service: AIService) {
        guard let webView = webviews[service.id],
              let window = webView.window else { return }
        
        window.makeFirstResponder(webView)
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webviews {
            if storedWebView === webView {
                updateLoadingStatus(for: serviceId, isLoading: false)
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webviews {
            if storedWebView === webView {
                updateLoadingStatus(for: serviceId, isLoading: true)
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webviews {
            if storedWebView === webView {
                updateLoadingStatus(for: serviceId, isLoading: false)
                break
            }
        }
    }
    
    // MARK: - WKUIDelegate Methods
    
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

// Persistent WebView that uses the WebViewManager
struct PersistentWebView: NSViewRepresentable {
    let service: AIService
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> NSView {
        // Create a container view
        let containerView = NSView(frame: .zero)
        
        // Get the webview for this service from the manager
        let webView = WebViewManager.shared.getWebView(for: service)
        webView.frame = containerView.bounds
        webView.autoresizingMask = [.width, .height]
        
        // Add the webview to the container
        containerView.addSubview(webView)
        
        // Update loading status
        isLoading = WebViewManager.shared.isServiceLoading(service)
        
        // Focus the webview
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let window = webView.window {
                window.makeFirstResponder(webView)
            }
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update loading status
        isLoading = WebViewManager.shared.isServiceLoading(service)
        
        // Focus the webview if it's visible
        DispatchQueue.main.async {
            if let webView = nsView.subviews.first as? WKWebView,
               let window = webView.window,
               !webView.isHidden {
                window.makeFirstResponder(webView)
            }
        }
    }
}

// Original coordinator class (kept for compatibility)
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

// Original AIWebView (kept for compatibility)
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
        // Use the WebViewManager to get the webview for this service
        return WebViewManager.shared.getWebView(for: service)
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update loading status
        isLoading = WebViewManager.shared.isServiceLoading(service)
        
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
            
            PersistentWebView(service: service, isLoading: $isLoading)
        }
    }
} 