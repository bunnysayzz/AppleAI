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
    
    // Dictionary to track keyboard shortcut injection timers for each webview
    private var keyboardShortcutTimers: [WKWebView: Timer] = [:]
    
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
        
        // Clean up all keyboard shortcut timers
        for timer in keyboardShortcutTimers.values {
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
        
        // Register for key events (this helps to ensure the web view gets keyboard events)
        let keyEvents: [NSEvent.EventTypeMask] = [.keyDown, .keyUp, .flagsChanged]
        for eventMask in keyEvents {
            NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak webView] event in
                if let webView = webView, webView.window?.firstResponder == webView {
                    return event
                }
                return event
            }
        }
        
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
                
                // Inject keyboard shortcut handlers
                injectKeyboardShortcutHandlers(webView)
                
                // Inject service-specific handlers
                if let service = aiServices.first(where: { $0.id == serviceId }) {
                    injectServiceSpecificHandlers(webView, for: service)
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
    
    // Function to inject JavaScript for keyboard shortcuts (copy, paste, select all)
    private func injectKeyboardShortcutHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check if we've already injected this script
            if (window._keyboardShortcutsInjected) return;
            window._keyboardShortcutsInjected = true;
            
            // Store original event handlers
            const originalKeyDown = document.onkeydown;
            
            // Map keyCodes to their actions for easier reference
            const KEY_ACTIONS = {
                65: 'selectall',  // A
                67: 'copy',       // C
                86: 'paste',      // V
                88: 'cut'         // X
            };
            
            // Add event listener to ensure keyboard shortcuts work
            document.addEventListener('keydown', function(e) {
                // Handle only cmd/ctrl key combinations
                if (!(e.metaKey || e.ctrlKey)) return;
                
                const keyCode = e.keyCode || e.which;
                const action = KEY_ACTIONS[keyCode];
                
                if (!action) return; // Not a shortcut we're handling
                
                // Get the active/focused element
                const activeElement = document.activeElement;
                const isEditable = activeElement && (
                    activeElement.isContentEditable || 
                    activeElement.tagName === 'INPUT' || 
                    activeElement.tagName === 'TEXTAREA' || 
                    activeElement.tagName === 'SELECT' ||
                    activeElement.role === 'textbox' ||
                    activeElement.getAttribute('contenteditable') === 'true'
                );
                
                // Handle Select All (Cmd+A)
                if (action === 'selectall' && isEditable) {
                    if (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') {
                        setTimeout(function() {
                            activeElement.select();
                        }, 0);
                    } else if (activeElement.isContentEditable || activeElement.getAttribute('contenteditable') === 'true') {
                        // For contentEditable elements, select all text inside
                        setTimeout(function() {
                            const selection = window.getSelection();
                            const range = document.createRange();
                            range.selectNodeContents(activeElement);
                            selection.removeAllRanges();
                            selection.addRange(range);
                        }, 0);
                    }
                    // Don't prevent default for other elements to allow browser's native select all
                }
                
                // For editable fields, we'll ensure the native behavior works
                if (isEditable) {
                    // We intentionally don't preventDefault to allow native handling in inputs
                    // This often works better than custom implementation
                    console.log('Native keyboard shortcut handling: ' + action);
                }
                
                // Let original event handler run if it exists
                if (typeof originalKeyDown === 'function') {
                    return originalKeyDown.call(this, e);
                }
            }, true);
            
            // Add a mutation observer to handle dynamically added elements
            const observer = new MutationObserver(function(mutations) {
                // Check if important UI elements that handle keyboard input have been added
                mutations.forEach(mutation => {
                    if (mutation.addedNodes && mutation.addedNodes.length) {
                        for (let i = 0; i < mutation.addedNodes.length; i++) {
                            const node = mutation.addedNodes[i];
                            if (node.nodeType === 1) { // Element node
                                // Ensure our handlers are applied to new inputs
                                if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA' || 
                                    node.getAttribute('contenteditable') === 'true' ||
                                    node.isContentEditable) {
                                    // This is an input element, make sure it will work with keyboard shortcuts
                                    console.log('New input element detected, ensuring keyboard shortcuts work');
                                }
                                
                                // Also check children
                                const inputs = node.querySelectorAll('input, textarea, [contenteditable="true"]');
                                if (inputs.length) {
                                    console.log('New input elements found within added node');
                                }
                            }
                        }
                    }
                });
            });
            
            // Start observing body for changes
            observer.observe(document.body, { 
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['contenteditable', 'class', 'id']
            });
            
            // Override execCommand for better copy/paste/cut support
            const originalExecCommand = document.execCommand;
            document.execCommand = function(command, showUI, value) {
                console.log('ExecCommand called:', command);
                return originalExecCommand.call(this, command, showUI, value);
            };
            
            console.log('Enhanced keyboard shortcuts handlers injected successfully');
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting keyboard shortcut handlers: \(error)")
            } else {
                print("Successfully injected keyboard shortcut handlers")
                
                // Schedule periodic reinjection to ensure shortcuts keep working
                self.scheduleKeyboardShortcutsReinject(webView)
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
                            if let error = error {
                                print("Error simulating file upload: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Function to periodically re-inject the keyboard shortcuts
    private func scheduleKeyboardShortcutsReinject(_ webView: WKWebView) {
        // Cancel any existing timer for this webview
        if let existingTimer = keyboardShortcutTimers[webView] {
            existingTimer.invalidate()
            keyboardShortcutTimers.removeValue(forKey: webView)
        }
        
        // Create a new timer
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak webView] timer in
            guard let self = self, let webView = webView else {
                timer.invalidate()
                return
            }
            
            // Check if the webview is visible
            if !webView.isHidden {
                // Re-apply the keyboard shortcuts script
                let checkScript = """
                if (!window._keyboardShortcutsInjected) {
                    true;
                } else {
                    false;
                }
                """
                
                webView.evaluateJavaScript(checkScript) { (result, error) in
                    if let needsReinject = result as? Bool, needsReinject {
                        self.injectKeyboardShortcutHandlers(webView)
                    }
                }
            }
        }
        
        // Store the timer
        keyboardShortcutTimers[webView] = timer
    }
    
    // Function to inject service-specific JavaScript handlers
    private func injectServiceSpecificHandlers(_ webView: WKWebView, for service: AIService) {
        switch service.name {
        case "ChatGPT":
            injectChatGPTKeyboardHandlers(webView)
        case "Claude":
            injectClaudeKeyboardHandlers(webView)
        case "Copilot":
            injectCopilotKeyboardHandlers(webView)
        case "Perplexity":
            injectPerplexityKeyboardHandlers(webView)
        case "Grok":
            injectGrokKeyboardHandlers(webView)
        default:
            // General handlers already applied
            break
        }
    }
    
    // ChatGPT specific keyboard handlers
    private func injectChatGPTKeyboardHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Focus on ensuring clipboard operations work in the textarea
            function enhanceChatGPTTextareas() {
                const textareas = document.querySelectorAll('[data-testid="chat-input-textarea"]');
                textareas.forEach(textarea => {
                    if (!textarea.dataset.keyboardEnhanced) {
                        textarea.dataset.keyboardEnhanced = "true";
                        
                        // Ensure paste works
                        textarea.addEventListener('paste', function(e) {
                            // Let the browser handle paste
                            console.log('Paste event in ChatGPT textarea');
                        });
                        
                        // Ensure copy works
                        textarea.addEventListener('copy', function(e) {
                            // Let the browser handle copy
                            console.log('Copy event in ChatGPT textarea');
                        });
                        
                        // Ensure cut works
                        textarea.addEventListener('cut', function(e) {
                            // Let the browser handle cut
                            console.log('Cut event in ChatGPT textarea');
                        });
                    }
                });
            }
            
            // Run immediately
            enhanceChatGPTTextareas();
            
            // Set up a MutationObserver to handle dynamically added elements
            const observer = new MutationObserver(function() {
                enhanceChatGPTTextareas();
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting ChatGPT keyboard handlers: \(error)")
            } else {
                print("Successfully injected ChatGPT keyboard handlers")
            }
        }
    }
    
    // Claude specific keyboard handlers
    private func injectClaudeKeyboardHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Focus on ensuring clipboard operations work in Claude's input area
            function enhanceClaudeInputs() {
                // Claude uses a contenteditable div for input
                const inputAreas = document.querySelectorAll('[contenteditable="true"]');
                inputAreas.forEach(input => {
                    if (!input.dataset.keyboardEnhanced) {
                        input.dataset.keyboardEnhanced = "true";
                        
                        // Custom select all handler for contenteditable
                        input.addEventListener('keydown', function(e) {
                            if (e.metaKey && e.key === 'a') {
                                e.preventDefault();
                                const selection = window.getSelection();
                                const range = document.createRange();
                                range.selectNodeContents(input);
                                selection.removeAllRanges();
                                selection.addRange(range);
                                return false;
                            }
                        });
                    }
                });
            }
            
            // Run immediately
            enhanceClaudeInputs();
            
            // Set up a MutationObserver to handle dynamically added elements
            const observer = new MutationObserver(function() {
                enhanceClaudeInputs();
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting Claude keyboard handlers: \(error)")
            } else {
                print("Successfully injected Claude keyboard handlers")
            }
        }
    }
    
    // Copilot specific keyboard handlers
    private func injectCopilotKeyboardHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Focus on ensuring clipboard operations work in Copilot's textarea
            function enhanceCopilotInputs() {
                // Copilot usually uses a standard textarea
                const textareas = document.querySelectorAll('textarea');
                textareas.forEach(textarea => {
                    if (!textarea.dataset.keyboardEnhanced) {
                        textarea.dataset.keyboardEnhanced = "true";
                        
                        // Ensure cmd+a works 
                        textarea.addEventListener('keydown', function(e) {
                            if (e.metaKey && e.key === 'a') {
                                textarea.select();
                                e.preventDefault();
                                return false;
                            }
                        });
                    }
                });
            }
            
            // Run immediately
            enhanceCopilotInputs();
            
            // Set up a MutationObserver to handle dynamically added elements
            const observer = new MutationObserver(function() {
                enhanceCopilotInputs();
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting Copilot keyboard handlers: \(error)")
            } else {
                print("Successfully injected Copilot keyboard handlers")
            }
        }
    }
    
    // Perplexity specific keyboard handlers
    private func injectPerplexityKeyboardHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Focus on ensuring clipboard operations work in Perplexity's input
            function enhancePerplexityInputs() {
                // Perplexity often uses a textarea or contenteditable div
                const inputs = [...document.querySelectorAll('textarea'), ...document.querySelectorAll('[contenteditable="true"]')];
                inputs.forEach(input => {
                    if (!input.dataset.keyboardEnhanced) {
                        input.dataset.keyboardEnhanced = "true";
                        
                        // For contenteditable divs
                        if (input.getAttribute('contenteditable') === 'true') {
                            input.addEventListener('keydown', function(e) {
                                if (e.metaKey && e.key === 'a') {
                                    e.preventDefault();
                                    const selection = window.getSelection();
                                    const range = document.createRange();
                                    range.selectNodeContents(input);
                                    selection.removeAllRanges();
                                    selection.addRange(range);
                                    return false;
                                }
                            });
                        }
                    }
                });
            }
            
            // Run immediately
            enhancePerplexityInputs();
            
            // Set up a MutationObserver to handle dynamically added elements
            const observer = new MutationObserver(function() {
                enhancePerplexityInputs();
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting Perplexity keyboard handlers: \(error)")
            } else {
                print("Successfully injected Perplexity keyboard handlers")
            }
        }
    }
    
    // Grok specific keyboard handlers
    private func injectGrokKeyboardHandlers(_ webView: WKWebView) {
        let script = """
        (function() {
            // Focus on ensuring clipboard operations work in Grok's input area
            function enhanceGrokInputs() {
                // Grok typically uses textareas or contenteditable divs
                const inputs = document.querySelectorAll('textarea, [contenteditable="true"], [role="textbox"]');
                
                inputs.forEach(input => {
                    if (!input.dataset.keyboardEnhanced) {
                        input.dataset.keyboardEnhanced = "true";
                        
                        // Ensure keyboard shortcuts work
                        input.addEventListener('keydown', function(e) {
                            if (e.metaKey || e.ctrlKey) {
                                // For contenteditable divs, handle select all
                                if ((e.key === 'a' || e.keyCode === 65) && 
                                    (input.getAttribute('contenteditable') === 'true' || input.getAttribute('role') === 'textbox')) {
                                    e.preventDefault();
                                    const selection = window.getSelection();
                                    const range = document.createRange();
                                    range.selectNodeContents(input);
                                    selection.removeAllRanges();
                                    selection.addRange(range);
                                    return false;
                                }
                            }
                        });
                        
                        // Ensure all input events propagate correctly
                        ['copy', 'paste', 'cut', 'input', 'select'].forEach(eventType => {
                            input.addEventListener(eventType, function(e) {
                                console.log('Grok input event:', eventType);
                            });
                        });
                    }
                });
                
                // Special handling for Grok's custom editor if it exists
                const grokEditor = document.querySelector('[data-testid="chat-input"]');
                if (grokEditor && !grokEditor.dataset.keyboardEnhanced) {
                    grokEditor.dataset.keyboardEnhanced = "true";
                    console.log('Enhanced Grok editor found and keyboard shortcuts enabled');
                }
            }
            
            // Run immediately
            enhanceGrokInputs();
            
            // Set up a MutationObserver to handle dynamically added elements
            const observer = new MutationObserver(function() {
                enhanceGrokInputs();
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting Grok keyboard handlers: \(error)")
            } else {
                print("Successfully injected Grok keyboard handlers")
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

// New KeyboardResponderView to help with keyboard shortcuts
class KeyboardResponderView: NSView {
    weak var webView: WKWebView?
    
    override var acceptsFirstResponder: Bool { return true }
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        
        // Set up to receive keyboard events
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Ensure we're getting key events by becoming first responder
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = self.window {
            window.makeFirstResponder(self)
        }
    }
    
    // Pass through standard keyboard shortcuts
    override func keyDown(with event: NSEvent) {
        // Handle copy, paste, select all shortcuts
        if event.modifierFlags.contains(.command) {
            let handled = handleStandardShortcut(event)
            if handled {
                return
            }
        }
        
        // Pass the event to the web view
        if let webView = webView {
            webView.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // Pass through all keyboard related events
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Pass command key combos to the web view - this is critical for shortcuts
        if event.modifierFlags.contains(.command) {
            if handleStandardShortcut(event) {
                return true
            }
        }
        
        // Let the web view handle other key equivalents
        if let webView = webView {
            return webView.performKeyEquivalent(with: event)
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    // Helper method to handle standard keyboard shortcuts
    private func handleStandardShortcut(_ event: NSEvent) -> Bool {
        guard let webView = webView else { return false }
        
        // Keyboard shortcuts map
        let shortcuts: [UInt16: Selector] = [
            0x00: #selector(NSText.selectAll(_:)),          // A - Select All
            0x08: #selector(NSText.copy(_:)),               // C - Copy
            0x09: #selector(NSText.paste(_:)),              // V - Paste
            0x07: #selector(NSText.cut(_:)),                // X - Cut
            0x0C: #selector(NSText.delete(_:)),             // Z - Delete
            0x03: #selector(NSResponder.cancelOperation(_:)) // Escape
        ]
        
        // If this is a standard shortcut we're handling
        if let action = shortcuts[event.keyCode] {
            // Try the native action on the webView
            if webView.responds(to: action) {
                webView.performSelector(onMainThread: action, with: nil, waitUntilDone: false)
                return true
            }
            
            // Use JavaScript as a fallback for certain operations
            switch event.keyCode {
            case 0x00: // A - Select All
                webView.evaluateJavaScript("document.execCommand('selectAll', false, null);", completionHandler: nil)
                return true
            case 0x08: // C - Copy
                webView.evaluateJavaScript("document.execCommand('copy', false, null);", completionHandler: nil)
                return true
            case 0x09: // V - Paste
                webView.evaluateJavaScript("document.execCommand('paste', false, null);", completionHandler: nil)
                return true
            case 0x07: // X - Cut
                webView.evaluateJavaScript("document.execCommand('cut', false, null);", completionHandler: nil)
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    // Ensure mouse events pass through to the web view
    override func mouseDown(with event: NSEvent) {
        if let webView = webView {
            webView.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if let webView = webView {
            webView.mouseDragged(with: event)
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let webView = webView {
            webView.mouseUp(with: event)
        } else {
            super.mouseUp(with: event)
        }
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
            
            // Create a keyboard responder view for this web view
            let responderView = KeyboardResponderView(webView: webView)
            responderView.frame = containerView.bounds
            responderView.autoresizingMask = [.width, .height]
            
            // Add the responder view to the container
            containerView.addSubview(responderView)
            
            // Add the webview to the responder view
            responderView.addSubview(webView)
            
            // Only show the selected webview
            responderView.isHidden = cachedService.id != service.id
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
            if let responderView = subview as? KeyboardResponderView {
                // Find which service this responder's webview belongs to
                if let webView = responderView.webView {
                    for cachedService in aiServices {
                        if webView === WebViewCache.shared.getWebView(for: cachedService) {
                            // Set visibility based on whether this is the selected service
                            responderView.isHidden = cachedService.id != service.id
                        }
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
            // First try to find the keyboard responder view for the current service
            if let responderView = containerView.subviews.first(where: { 
                !$0.isHidden && $0 is KeyboardResponderView
            }) as? KeyboardResponderView,
               let window = responderView.window {
                // Make the responder view the first responder
                window.makeFirstResponder(responderView)
            } 
            // Fallback to directly focus the web view if needed
            else if let webView = containerView.subviews.first(where: { 
                !$0.isHidden && NSStringFromClass(type(of: $0)).contains("WKWebView")
            }) as? WKWebView,
               let window = webView.window {
                window.makeFirstResponder(webView)
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