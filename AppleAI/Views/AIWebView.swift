@preconcurrency
import SwiftUI
@preconcurrency import WebKit

// Global WebView cache to store and reuse webviews
class WebViewCache: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = WebViewCache()
    
    private var webViews: [UUID: WKWebView] = [:]
    @Published var loadingStates: [UUID: Bool] = [:]
    private var chatGPTTimers: [WKWebView: Timer] = [:] // Track timers to avoid duplicates
    
    // Track when a file picker is active to prevent window hiding
    @Published var isFilePickerActive: Bool = false
    
    override private init() {
        super.init()
        // Preload all service webviews on initialization
        preloadWebViews()
    }
    
    deinit {
        // Clean up all timers
        for timer in chatGPTTimers.values {
            timer.invalidate()
        }
    }
    
    private func preloadWebViews() {
        for service in aiServices {
            let webView = createWebView(for: service)
            webViews[service.id] = webView
            loadingStates[service.id] = true
        }
    }
    
    func getWebView(for service: AIService) -> WKWebView {
        if let existingWebView = webViews[service.id] {
            return existingWebView
        }
        
        let webView = createWebView(for: service)
        webViews[service.id] = webView
        return webView
    }
    
    private func createWebView(for service: AIService) -> WKWebView {
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
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Configure to receive and handle keyboard events
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.wantsLayer = true
        
        // Load the URL
        webView.load(URLRequest(url: service.url))
        
        // Track last usage time
        UserDefaults.standard.set(Date(), forKey: "lastUsed_\(service.name)")
        
        return webView
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = false
                }
                
                // Check if this is ChatGPT and inject JavaScript to handle enter key
                if let service = aiServices.first(where: { $0.id == serviceId }),
                   service.name == "ChatGPT" {
                    injectChatGPTEnterKeyHandler(webView)
                }
                
                break
            }
        }
    }
    
    // Function to inject JavaScript for ChatGPT to make Enter send message
    private func injectChatGPTEnterKeyHandler(_ webView: WKWebView) {
        let script = """
        document.addEventListener('keydown', function(e) {
            // Check if this is the Enter key without shift
            if (e.key === 'Enter' && !e.shiftKey) {
                // Find the send button
                const sendButton = document.querySelector('button[data-testid="send-button"]');
                
                // If we found the send button
                if (sendButton) {
                    // Prevent default action (new line)
                    e.preventDefault();
                    
                    // Click the send button
                    sendButton.click();
                    
                    // Return to prevent further handling
                    return false;
                }
            }
        }, true);
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting ChatGPT Enter key handler: \(error)")
            } else {
                print("Successfully injected ChatGPT Enter key handler")
                
                // Schedule periodic reinjection as ChatGPT is a SPA and might rebuild UI
                self.scheduleChatGPTEnterKeyReinject(webView)
            }
        }
    }
    
    // Function to periodically re-inject the script
    private func scheduleChatGPTEnterKeyReinject(_ webView: WKWebView) {
        // Cancel any existing timer for this webview
        if let existingTimer = chatGPTTimers[webView] {
            existingTimer.invalidate()
            chatGPTTimers.removeValue(forKey: webView)
        }
        
        // Create a new timer
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak webView] timer in
            guard let self = self, let webView = webView else {
                timer.invalidate()
                return
            }
            
            // For any service ID that matches ChatGPT, check if the webview is visible
            for (serviceId, storedWebView) in self.webViews {
                if storedWebView === webView,
                   let service = aiServices.first(where: { $0.id == serviceId }),
                   service.name == "ChatGPT",
                   !webView.isHidden {
                    // If it's visible, reapply the script
                    let checkScript = """
                    if (!window._chatGPTEnterHandlerActive) {
                        window._chatGPTEnterHandlerActive = true;
                        true;
                    } else {
                        false;
                    }
                    """
                    
                    webView.evaluateJavaScript(checkScript) { (result, error) in
                        if let needsReinject = result as? Bool, needsReinject {
                            self.injectChatGPTEnterKeyHandler(webView)
                        }
                    }
                    
                    break
                }
            }
        }
        
        // Store the timer
        chatGPTTimers[webView] = timer
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = true
                }
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Find the service ID for this webview
        for (serviceId, storedWebView) in webViews {
            if storedWebView === webView {
                DispatchQueue.main.async {
                    self.loadingStates[serviceId] = false
                }
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
    
    // Add support for file uploads
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        
        // Set file picker as active
        isFilePickerActive = true
        
        // Check file type filtering if available, but skip for older macOS versions
        if #available(macOS 11.0, *) {
            // Check if there's a way to get allowed file types
            // We can't use allowedContentTypes or allowsAllTypes directly
        }
        
        openPanel.begin { [weak self] (result) in
            // Reset file picker active state
            self?.isFilePickerActive = false
            
            if result == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    // Function to manually trigger file upload for any service
    func triggerFileUpload(for service: AIService) {
        guard let webView = webViews[service.id] else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.message = "Select files to upload"
        openPanel.prompt = "Upload"
        
        // Set file picker as active
        isFilePickerActive = true
        
        openPanel.begin { [weak self] (result) in
            guard let self = self else { return }
            
            // Reset file picker active state
            self.isFilePickerActive = false
            
            if result == .OK {
                let urls = openPanel.urls
                
                // Focus the webView first
                if let window = webView.window {
                    window.makeFirstResponder(webView)
                }
                
                // Find the appropriate file input in the webView and simulate a file selection
                // This script tries to find a file input and click it to trigger file selection UI
                // If the website has a custom file upload button, we need to click it
                let findAndClickFileInputScript = """
                (function() {
                    // Try to find visible file input
                    let fileInputs = Array.from(document.querySelectorAll('input[type="file"]'));
                    let visibleInput = fileInputs.find(input => {
                        let style = window.getComputedStyle(input);
                        return style.display !== 'none' && style.visibility !== 'hidden' && input.offsetWidth > 0;
                    });
                    
                    if (visibleInput) {
                        visibleInput.click();
                        return true;
                    }
                    
                    // Try to find file upload buttons
                    let uploadButtons = [];
                    
                    // ChatGPT
                    let chatgptButton = document.querySelector('button[aria-label="Attach files"]');
                    if (chatgptButton) {
                        uploadButtons.push(chatgptButton);
                    }
                    
                    // Claude
                    let claudeButton = document.querySelector('button[aria-label="Upload file"]');
                    if (claudeButton) {
                        uploadButtons.push(claudeButton);
                    }
                    
                    // Generic approach - look for buttons with upload-related text
                    const uploadKeywords = ['upload', 'file', 'attach', 'paperclip'];
                    document.querySelectorAll('button, a, div, span, i').forEach(element => {
                        const text = element.textContent?.toLowerCase() || '';
                        const ariaLabel = element.getAttribute('aria-label')?.toLowerCase() || '';
                        const classNames = element.className.toLowerCase();
                        
                        // Check if element or its children have upload-related info
                        const hasUploadKeyword = uploadKeywords.some(keyword => 
                            text.includes(keyword) || ariaLabel.includes(keyword) || classNames.includes(keyword)
                        );
                        
                        // Check for paperclip icons
                        const hasPaperclipIcon = element.querySelector('svg, img, i')?.className?.toLowerCase()?.includes('paperclip');
                        
                        if (hasUploadKeyword || hasPaperclipIcon) {
                            uploadButtons.push(element);
                        }
                    });
                    
                    if (uploadButtons.length > 0) {
                        uploadButtons[0].click();
                        return true;
                    }
                    
                    return false;
                })();
                """
                
                webView.evaluateJavaScript(findAndClickFileInputScript) { (result, error) in
                    if let success = result as? Bool, success {
                        print("Successfully clicked file input or upload button")
                    } else {
                        print("Could not find file input or upload button. Adding manual file upload support.")
                        
                        // If we couldn't find a proper file input, try to create one and simulate the file selection
                        let simulateFileUploadScript = """
                        (function() {
                            // Create a temporary file input if none found
                            const fileInput = document.createElement('input');
                            fileInput.type = 'file';
                            fileInput.multiple = true;
                            fileInput.style.display = 'none';
                            document.body.appendChild(fileInput);
                            
                            // Store references to important elements that we might need later
                            window.appleAITempFileInput = fileInput;
                            
                            // When files are selected, we'll try to handle them appropriately
                            fileInput.addEventListener('change', function() {
                                console.log('Files selected!', fileInput.files);
                                // We'll rely on the browser's file upload handling
                                
                                // Remove the element after use
                                setTimeout(() => {
                                    document.body.removeChild(fileInput);
                                    delete window.appleAITempFileInput;
                                }, 1000);
                            });
                            
                            // Trigger file selection dialog
                            fileInput.click();
                            return true;
                        })();
                        """
                        
                        webView.evaluateJavaScript(simulateFileUploadScript) { (result, error) in
                            if error != nil {
                                print("Error simulating file upload: \(error!)")
                            }
                        }
                    }
                }
            }
        }
    }
}

// A coordinator class to handle WKWebView callbacks
// Legacy coordinator kept for compatibility
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

// New persistent WebView that uses the cache
struct PersistentWebView: NSViewRepresentable {
    let service: AIService
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> NSView {
        // Create a container view
        let containerView = NSView(frame: .zero)
        
        // Create all webviews for all services and add them to the container
        // But only show the selected one
        for cachedService in aiServices {
            let webView = WebViewCache.shared.getWebView(for: cachedService)
            webView.frame = containerView.bounds
            webView.autoresizingMask = [.width, .height]
            
            // Add the webview to the container
            containerView.addSubview(webView)
            
            // Only show the selected webview
            webView.isHidden = cachedService.id != service.id
        }
        
        // Update loading status
        isLoading = WebViewCache.shared.loadingStates[service.id] ?? true
        
        // Focus the current webview
        focusCurrentWebView(in: containerView)
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update loading status
        isLoading = WebViewCache.shared.loadingStates[service.id] ?? true
        
        // Show only the selected webview, hide all others
        for subview in nsView.subviews {
            if let webView = subview as? WKWebView {
                // Find which service this webview belongs to
                for cachedService in aiServices {
                    if webView === WebViewCache.shared.getWebView(for: cachedService) {
                        // Set visibility based on whether this is the selected service
                        webView.isHidden = cachedService.id != service.id
                    }
                }
            }
        }
        
        // Focus the current webview
        focusCurrentWebView(in: nsView)
    }
    
    private func focusCurrentWebView(in containerView: NSView) {
        // Focus the webview for the current service
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let currentWebView = containerView.subviews.first(where: { !$0.isHidden }) as? WKWebView,
               let window = currentWebView.window {
                window.makeFirstResponder(currentWebView)
            }
        }
    }
}

// Original AIWebView (kept for backwards compatibility)
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
        // Use the WebViewCache to get the webview for this service
        return WebViewCache.shared.getWebView(for: service)
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update loading status
        isLoading = WebViewCache.shared.loadingStates[service.id] ?? true
        
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
        VStack(spacing: 0) {
            // Colored divider for visual separation - just keep this
            Rectangle()
                .frame(height: 2)
                .foregroundColor(service.color)
            
            // WebView content area
            PersistentWebView(service: service, isLoading: $isLoading)
                .onChange(of: service) { newService in
                    // When service changes, ensure the loading status is updated
                    isLoading = WebViewCache.shared.loadingStates[newService.id] ?? true
                }
                .onAppear {
                    // Short delay to ensure view is fully loaded before attempting to set focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let window = NSApplication.shared.keyWindow {
                            // Attempt to find and focus the webView for this service
                            let currentWebView = WebViewCache.shared.getWebView(for: service)
                            window.makeFirstResponder(currentWebView)
                        }
                    }
                }
        }
    }
} 