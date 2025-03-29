@preconcurrency
import SwiftUI
@preconcurrency import WebKit
import AVFoundation

// Global WebView cache to store and reuse webviews
class WebViewCache: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let shared = WebViewCache()
    
    @Published private var webViews: [String: WKWebView] = [:]
    @Published var loadingStates: [String: Bool] = [:]
    private var chatGPTTimers: [WKWebView: Timer] = [:] // Track timers to avoid duplicates
    
    // Track when a file picker is active to prevent window hiding
    @Published var isFilePickerActive: Bool = false
    
    // Dictionary to track keyboard shortcut injection timers for each webview
    private var keyboardShortcutTimers: [WKWebView: Timer] = [:]
    
    // Track voice chat activity state
    private var isVoiceChatActive: Bool = false
    
    private var lastVoiceActivityTime: Date? = nil
    
    // Add currentServiceID property to track the active service
    private var currentServiceID: String? = nil
    
    // Add microphone monitoring timer
    private var microphoneMonitorTimer: Timer?
    
    private override init() {
        super.init()
        // Preload all service webviews on initialization
        preloadWebViews()
        
        // Pre-request microphone permission at app startup
        DispatchQueue.main.async {
            self.requestMicrophonePermission()
        }
        
        // Start microphone monitoring
        startMicrophoneMonitoring()
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
        
        // Stop microphone monitoring
        stopMicrophoneMonitoring()
    }
    
    // Start monitoring for microphone activity
    private func startMicrophoneMonitoring() {
        // Stop existing timer if any
        stopMicrophoneMonitoring()
        
        // Create timer to check microphone usage every 500ms
        microphoneMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkMicrophoneActivity()
        }
    }
    
    // Stop microphone monitoring
    private func stopMicrophoneMonitoring() {
        microphoneMonitorTimer?.invalidate()
        microphoneMonitorTimer = nil
    }
    
    // Check if microphone is being used
    private func checkMicrophoneActivity() {
        // Skip check if we know voice chat is active and recent
        if isVoiceChatActive, let lastActivity = lastVoiceActivityTime, 
           Date().timeIntervalSince(lastActivity) < 2.0 {
            return
        }
        
        // For each webview, check for active microphone
        for (_, webView) in webViews {
            if !webView.isHidden {
                checkWebViewMicrophoneActivity(webView)
            }
        }
        
        // If voice chat was marked as active but no activity for a while, stop it
        if isVoiceChatActive, let lastActivity = lastVoiceActivityTime,
           Date().timeIntervalSince(lastActivity) > 10.0 {
            print("No voice activity detected for 10 seconds - stopping microphone")
            stopAllMicrophoneUse()
        }
    }
    
    // Check if a specific webview is using the microphone
    private func checkWebViewMicrophoneActivity(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check for active audio streams
            let hasActiveAudio = false;
            
            // Check active streams
            if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                for (const stream of window.activeAudioStreams) {
                    if (stream && typeof stream.getTracks === 'function') {
                        const audioTracks = stream.getTracks().filter(track => 
                            track.kind === 'audio' && track.readyState === 'live'
                        );
                        if (audioTracks.length > 0) {
                            hasActiveAudio = true;
                            break;
                        }
                    }
                }
            }
            
            // Also check for voice UI
            let voiceChatUIVisible = false;
            
            // ChatGPT voice UI
            const chatGptUI = document.querySelectorAll('[data-testid="voice-message-recording-indicator"], [aria-label="Stop recording"]');
            if (chatGptUI.length > 0) {
                voiceChatUIVisible = true;
            }
            
            // Claude voice UI
            const claudeUI = document.querySelectorAll('.voice-recording, [aria-label="Stop listening"]');
            if (claudeUI.length > 0) {
                voiceChatUIVisible = true;
            }
            
            // Generic voice UI
            const genericUI = document.querySelectorAll('.voice-input-active, .recording-active, [data-voice-active="true"]');
            if (genericUI.length > 0) {
                voiceChatUIVisible = true;
            }
            
            return { hasActiveAudio, voiceChatUIVisible };
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let result = result as? [String: Bool],
               let hasActiveAudio = result["hasActiveAudio"],
               let voiceChatUIVisible = result["voiceChatUIVisible"] {
                
                if hasActiveAudio || voiceChatUIVisible {
                    // We found an active voice chat
                    self.isVoiceChatActive = true
                    self.lastVoiceActivityTime = Date()
                } else if self.isVoiceChatActive {
                    // Check if it's been inactive for a bit before changing state
                    if let lastActivity = self.lastVoiceActivityTime,
                       Date().timeIntervalSince(lastActivity) > 3.0 {
                        // No activity for 3 seconds, prepare to stop
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.stopAllMicrophoneUse()
                        }
                    }
                }
            }
        }
    }
    
    // Function to inject JavaScript to handle microphone permissions
    private func injectMicrophonePermissionHandlers(_ webView: WKWebView) {
        // First, check current permission status
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let statusString = currentStatus == .authorized ? "granted" : "not granted"
        
        let script = """
        (function() {
            // Store permission status and keep track of attempts
            if (!window._microphonePermissionState) {
                window._microphonePermissionState = {
                    status: '\(statusString)',
                    requestAttempts: 0,
                    lastRequestTime: null,
                    buttonsWithListeners: new Set()
                };
            }
            
            // Store active audio streams and contexts to stop them later
            if (!window.activeAudioStreams) {
                window.activeAudioStreams = [];
            }
            
            // Override getUserMedia method to check our state before requesting
            const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
            navigator.mediaDevices.getUserMedia = async function(constraints) {
                console.log('getUserMedia called with constraints:', constraints);
                
                // If audio is requested, manage permission state
                if (constraints && constraints.audio) {
                    // Don't allow rapid repeated requests
                    const now = Date.now();
                    const minTimeBetweenRequests = 5000; // 5 seconds
                    
                    if (window._microphonePermissionState.lastRequestTime && 
                        (now - window._microphonePermissionState.lastRequestTime) < minTimeBetweenRequests) {
                        console.log('Throttling permission request to prevent repeated dialogs');
                        
                        // If we've already been granted permission, proceed
                        if (window._microphonePermissionState.status === 'granted') {
                            return await originalGetUserMedia.call(this, constraints);
                        }
                        
                        // Otherwise throw an appropriate error
                        const error = new DOMException('Permission request throttled to prevent multiple dialogs', 'NotAllowedError');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionThrottled',
                            error: error.toString()
                        });
                        throw error;
                    }
                    
                    // Update state
                    window._microphonePermissionState.lastRequestTime = now;
                    window._microphonePermissionState.requestAttempts++;
                    
                    console.log('Requesting microphone permission, attempt #' + window._microphonePermissionState.requestAttempts);
                    
                    try {
                        // This will trigger the permission dialog if needed
                        const stream = await originalGetUserMedia.call(this, constraints);
                        
                        // Store the stream for later cleanup
                        window.activeAudioStreams.push(stream);
                        
                        // Add a listener to detect when the stream ends
                        stream.addEventListener('inactive', function() {
                            console.log('Audio stream became inactive');
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'streamEnded',
                                reason: 'inactive'
                            });
                            
                            // Remove this stream from active streams
                            const index = window.activeAudioStreams.indexOf(stream);
                            if (index !== -1) {
                                window.activeAudioStreams.splice(index, 1);
                            }
                        });
                        
                        // Also add listeners to all tracks
                        stream.getTracks().forEach(track => {
                            if (track.kind === 'audio') {
                                track.addEventListener('ended', function() {
                                    console.log('Audio track ended');
                                    window.webkit.messageHandlers.mediaPermission.postMessage({
                                        type: 'streamEnded',
                                        reason: 'trackEnded'
                                    });
                                    
                                    // Cleanup stream references after a track ends
                                    const index = window.activeAudioStreams.indexOf(stream);
                                    if (index !== -1) {
                                        window.activeAudioStreams.splice(index, 1);
                                    }
                                });
                            }
                        });
                        
                        // Update our state on success
                        window._microphonePermissionState.status = 'granted';
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionGranted',
                            source: 'getUserMedia'
                        });
                        
                        // Notify about voice chat activity
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'voiceChatStarted'
                        });
                        
                        return stream;
                    } catch (error) {
                        console.error('Error getting microphone access:', error);
                        
                        // Update our state on failure
                        if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                            window._microphonePermissionState.status = 'denied';
                        }
                        
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionError',
                            error: error.toString(),
                            errorName: error.name
                        });
                        
                        throw error;
                    }
                }
                
                // For other requests, use the original implementation
                return await originalGetUserMedia.call(this, constraints);
            };
            
            // Add function to stop all audio tracks
            window.stopAllAudioTracks = function() {
                console.log('Stopping all audio tracks');
                
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => {
                        if (stream && typeof stream.getTracks === 'function') {
                            stream.getTracks().forEach(track => {
                                if (track.kind === 'audio') {
                                    track.stop();
                                    console.log('Stopped audio track');
                                }
                            });
                        }
                    });
                    
                    // Clear the list
                    window.activeAudioStreams = [];
                }
                
                // Close any audio contexts
                if (window.activeAudioContext) {
                    try {
                        window.activeAudioContext.close();
                        window.activeAudioContext = null;
                    } catch (e) {
                        console.error('Error closing audio context:', e);
                    }
                }
                
                return true;
            };
            
            // Also hook into any voice recognition buttons or elements
            function setupVoiceButtonListeners() {
                // Look for typical voice input buttons across different AI platforms
                const voiceSelectors = [
                    'button[aria-label*="voice"]',
                    'button[aria-label*="microphone"]',
                    'button[aria-label*="speech"]',
                    'button[aria-label*="talk"]',
                    'button[title*="voice"]',
                    'button[title*="microphone"]',
                    'button[title*="speech"]',
                    'button[title*="talk"]',
                    'button[class*="voice"]',
                    'button[class*="microphone"]',
                    'button[class*="speech"]',
                    'button[class*="talk"]',
                    'button[id*="voice"]',
                    'button[id*="microphone"]',
                    'button[id*="speech"]',
                    'button[id*="talk"]',
                    'svg[aria-label*="voice"]',
                    'svg[aria-label*="microphone"]',
                    // ChatGPT specific
                    'button[data-testid="send-button-with-voice-control"]',
                    // Add more selectors as needed for specific platforms
                ];
                
                // Try to find any voice input buttons
                for (const selector of voiceSelectors) {
                    const elements = document.querySelectorAll(selector);
                    if (elements.length > 0) {
                        elements.forEach(element => {
                            // Only add listener if it doesn't already have one and we haven't tracked it
                            if (!element.dataset.micPermissionListener && 
                                !window._microphonePermissionState.buttonsWithListeners.has(element)) {
                                
                                element.dataset.micPermissionListener = 'true';
                                window._microphonePermissionState.buttonsWithListeners.add(element);
                                
                                // Add click listener for voice start
                                element.addEventListener('click', function(e) {
                                    console.log('Voice input element clicked');
                                    
                                    // Notify native app of button click
                                    window.webkit.messageHandlers.mediaPermission.postMessage({
                                        type: 'voiceButtonClicked',
                                        selector: selector
                                    });
                                });
                            }
                        });
                    }
                }
                
                // Also look for stop buttons
                const stopSelectors = [
                    'button[aria-label*="stop"]',
                    'button[title*="stop"]',
                    'button[aria-label*="cancel"]',
                    'button[title*="cancel"]',
                    'button.cancel',
                    'button.stop'
                ];
                
                for (const selector of stopSelectors) {
                    const elements = document.querySelectorAll(selector);
                    if (elements.length > 0) {
                        elements.forEach(element => {
                            if (!element.dataset.micStopListener) {
                                element.dataset.micStopListener = 'true';
                                
                                element.addEventListener('click', function() {
                                    console.log('Voice stop button clicked');
                                    
                                    // Notify the app that voice chat stopped
                                    window.webkit.messageHandlers.mediaPermission.postMessage({
                                        type: 'voiceChatStopped',
                                        reason: 'stopButton'
                                    });
                                    
                                    // Clean up streams
                                    window.stopAllAudioTracks();
                                });
                            }
                        });
                    }
                }
            }
            
            // Run immediately
            setupVoiceButtonListeners();
            
            // Also run when DOM changes to catch dynamically added elements
            const observer = new MutationObserver(setupVoiceButtonListeners);
            observer.observe(document.body, { 
                childList: true, 
                subtree: true 
            });
            
            // Setup ESC key handler for closing voice chat
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    // Check if any voice chat UI is visible
                    const voiceUIElements = document.querySelectorAll(
                        '[aria-label="Stop recording"], [aria-label="Stop voice input"], ' +
                        '.voice-recording, .voice-input-active, .recording-active, ' +
                        '[data-voice-active="true"], [data-testid="voice-message-recording-indicator"]'
                    );
                    
                    if (voiceUIElements.length > 0) {
                        setTimeout(() => {
                            // Check if UI disappeared after ESC
                            if (document.querySelectorAll(
                                '[aria-label="Stop recording"], [aria-label="Stop voice input"], ' +
                                '.voice-recording, .voice-input-active, .recording-active, ' +
                                '[data-voice-active="true"], [data-testid="voice-message-recording-indicator"]'
                            ).length === 0) {
                                console.log('Voice UI closed with ESC key');
                                window.webkit.messageHandlers.mediaPermission.postMessage({
                                    type: 'voiceChatStopped',
                                    reason: 'escKey'
                                });
                                
                                // Clean up streams
                                window.stopAllAudioTracks();
                            }
                        }, 100);
                    }
                }
            });
            
            console.log('Enhanced microphone permission handlers successfully injected');
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting microphone permission handlers: \(error)")
            } else {
                print("Successfully injected microphone permission handlers")
                
                // Also inject a UI monitor that checks every 500ms
                self.injectVoiceChatMonitor(webView)
            }
        }
    }
    
    // Inject a monitor to check voice chat UI state every 500ms
    private func injectVoiceChatMonitor(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check if monitor is already running
            if (window._voiceChatMonitorActive) return;
            window._voiceChatMonitorActive = true;
            
            console.log('Voice chat monitor started');
            
            // Function to check voice chat UI state
            function checkVoiceChatUI() {
                // Check for voice UI elements
                const voiceUIElements = document.querySelectorAll(
                    '[aria-label="Stop recording"], [aria-label="Stop voice input"], ' +
                    '.voice-recording, .voice-input-active, .recording-active, ' + 
                    '[data-voice-active="true"], [data-testid="voice-message-recording-indicator"]'
                );
                
                if (voiceUIElements.length > 0) {
                    // Voice UI is visible
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceActivityDetected'
                    });
                }
                
                // Also check for active audio tracks
                let hasActiveAudio = false;
                if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                    for (const stream of window.activeAudioStreams) {
                        if (stream && typeof stream.getTracks === 'function') {
                            const audioTracks = stream.getTracks().filter(track => 
                                track.kind === 'audio' && track.readyState === 'live'
                            );
                            if (audioTracks.length > 0) {
                                hasActiveAudio = true;
                                break;
                            }
                        }
                    }
                }
                
                if (hasActiveAudio) {
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceActivityDetected',
                        source: 'audioTracks'
                    });
                }
                
                // Return the result
                return { hasVoiceUI: voiceUIElements.length > 0, hasActiveAudio };
            }
            
            // Set up interval to check regularly
            const monitorInterval = setInterval(checkVoiceChatUI, 500);
            
            // Clean up when page is unloaded
            window.addEventListener('beforeunload', function() {
                clearInterval(monitorInterval);
                window._voiceChatMonitorActive = false;
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting voice chat monitor: \(error)")
            } else {
                print("Successfully injected voice chat monitor")
            }
        }
    }
    
    // Function to stop all microphone use
    func stopAllMicrophoneUse() {
        print("Stopping all microphone use in AIWebView")
        
        // For each webview, execute script to stop all audio streams
        for (_, webView) in webViews {
            webView.evaluateJavaScript("""
            (function() {
                console.log('Stopping all microphone use in web view');
                
                // Use the global function if available
                if (window.stopAllAudioTracks) {
                    return window.stopAllAudioTracks();
                }
                
                // Fallback implementation
                function stopTracks(stream) {
                    if (stream && typeof stream.getTracks === 'function') {
                        stream.getTracks().forEach(track => {
                            if (track.kind === 'audio') {
                                console.log('Stopping audio track manually');
                                track.stop();
                                track.enabled = false;
                            }
                        });
                    }
                }
                
                // Stop all active MediaStreams
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => {
                        stopTracks(stream);
                    });
                    
                    // Clear the list
                    window.activeAudioStreams = [];
                }
                
                // Reset voice chat UI elements if present
                const stopButtons = document.querySelectorAll('button[aria-label="Stop recording"], button[aria-label="Stop"]');
                stopButtons.forEach(button => button.click());
                
                return true;
            })();
            """) { (_, error) in
                if let error = error {
                    print("Error stopping microphone: \(error)")
                } else {
                    print("Successfully stopped microphone in webview")
                }
            }
        }
        
        // Reset state
        isVoiceChatActive = false
        lastVoiceActivityTime = nil
    }
    
    // Function to explicitly request microphone permission
    func requestMicrophonePermission() {
        // Check if we've already requested microphone permission
        let audioSession = AVCaptureDevice.authorizationStatus(for: .audio)
        
        // Only request permission if not already determined
        if audioSession == .notDetermined {
            print("Microphone permission not determined, requesting access")
            
            // Request permission
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                }
            }
        } else if audioSession == .authorized {
            print("Microphone permission already granted")
        } else if audioSession == .denied {
            print("Microphone permission already denied")
            
            // Show a message to the user explaining how to enable the permission
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Microphone Access Required"
                alert.informativeText = "Apple AI needs microphone access for voice chat features. Please enable it in System Settings > Privacy & Security > Microphone."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    // Open the Privacy & Security settings for microphone
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else if audioSession == .restricted {
            print("Microphone access is restricted")
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Handle script messages from the webview, especially for permissions
        if message.name == "mediaPermission" {
            print("Received message from JavaScript: \(message.body)")
            
            // If we received a message about permissions, log it but don't trigger keychain prompts
            if let messageBody = message.body as? [String: Any],
               let messageType = messageBody["type"] as? String {
                
                switch messageType {
                case "permissionDenied", "streamError", "permissionError":
                    // Log the error but don't show a system dialog that might trigger keychain
                    print("Microphone permission issue in webview: \(messageType)")
                    
                    // Request the permission through AVFoundation instead
                    // This avoids keychain prompts
                    let audioSession = AVCaptureDevice.authorizationStatus(for: .audio)
                    if audioSession == .authorized {
                        // Inject script to work around permission issues
                        injectPermissionFixer(message.webView)
                    }
                    
                    // Also set voice chat as inactive since there was an error
                    setVoiceChatActive(false)
                    
                case "voiceButtonClicked":
                    // Voice button was clicked, handle it silently
                    print("Voice button clicked in UI")
                    
                    // Set voice chat as active
                    setVoiceChatActive(true)
                    
                case "voiceChatStarted", "voiceInputActive", "recordingStarted":
                    // Voice recording is active
                    print("Voice recording started: \(messageType)")
                    setVoiceChatActive(true)
                    
                case "permissionGranted", "streamCreated":
                    print("Microphone permission success: \(messageType)")
                    
                    // When stream is created, voice chat is active
                    setVoiceChatActive(true)
                    
                    // Monitor this stream to detect when it ends
                    if let webView = message.webView, 
                       let streamInfo = messageBody["streamInfo"] as? [String: Any] {
                        monitorStreamStatus(webView, streamInfo: streamInfo)
                    }
                    
                case "streamEnded", "voiceChatStopped", "audioStopped", "recordingStopped":
                    print("Microphone stream ended: \(messageType)")
                    
                    // When stream ends, voice chat is no longer active
                    setVoiceChatActive(false)
                    
                case "voiceActivityDetected":
                    // Update the last activity time to prevent premature shutdown
                    if let webViewCache = WebViewCache.shared as? WebViewCache {
                        webViewCache.setVoiceChatActive(true)
                    }
                    
                default:
                    print("Unknown media permission message: \(messageType)")
                }
            }
        }
    }
    
    private func preloadWebViews() {
        for service in aiServices {
            let webView = createWebView(for: service)
            webViews[service.id.uuidString] = webView
            loadingStates[service.id.uuidString] = true
        }
    }
    
    func getWebView(for service: AIService) -> WKWebView {
        // Update the current service ID when accessing a webview
        updateCurrentServiceID(for: service)
        
        let serviceId = service.id.uuidString
        if let existingWebView = webViews[serviceId] {
            return existingWebView
        }
        
        let webView = createWebView(for: service)
        webViews[serviceId] = webView
        return webView
    }
    
    func createWebView(for service: AIService) -> WKWebView {
        // Create and configure a WKWebViewConfiguration
        let configuration = WKWebViewConfiguration()
        
        // Set up webpage preferences (macOS preferred way)
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        
        // Allow media playback without user action
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Create a new process pool for this configuration
        configuration.processPool = WKProcessPool()
        
        // Modify user agent to match desktop Safari
        configuration.applicationNameForUserAgent = "Version/15.0 Safari/605.1.15"
        
        // Configure for microphone access
        if #available(macOS 11.0, *) {
            // For macOS 11 and later, use the specific API
            configuration.allowsAirPlayForMediaPlayback = true
            configuration.userContentController.add(self, name: "mediaPermission")
            
            // Add script to request microphone permission immediately
            let immediatePermissionScript = """
            (function() {
                // Don't immediately request microphone permission as this causes repeated prompts
                // Instead, set up a handler that will properly request it when needed
                if (typeof navigator.mediaDevices !== 'undefined') {
                    // Log all permission requests
                    const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                    navigator.mediaDevices.getUserMedia = async function(constraints) {
                        console.log('getUserMedia called with:', constraints);
                        
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'getUserMediaCalled',
                            constraints: JSON.stringify(constraints)
                        });
                        
                        try {
                            const stream = await originalGetUserMedia.call(this, constraints);
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'streamCreated',
                                trackCount: stream.getTracks().length
                            });
                            return stream;
                        } catch (err) {
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'streamError',
                                error: err.toString()
                            });
                            throw err;
                        }
                    };
                }
            })();
            """
            
            // Add the userScript with immediate execution
            let userScript = WKUserScript(
                source: immediatePermissionScript, 
                injectionTime: .atDocumentStart, 
                forMainFrameOnly: false
            )
            configuration.userContentController.addUserScript(userScript)
        }
        
        // Create the web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Set initial URL from the service
        webView.load(URLRequest(url: service.url))
        
        // Set loading state
        loadingStates[service.id.uuidString] = true
        
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
                
                // Inject microphone permission handlers
                injectMicrophonePermissionHandlers(webView)
                
                // Inject service-specific handlers
                if let service = aiServices.first(where: { $0.id.uuidString == serviceId }) {
                    injectServiceSpecificHandlers(webView, for: service)
                }
                
                // Check if this is ChatGPT and inject JavaScript to handle enter key
                if let service = aiServices.first(where: { $0.id.uuidString == serviceId }),
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
                   let service = aiServices.first(where: { $0.id.uuidString == serviceId }),
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
        guard let webView = webViews[service.id.uuidString] else { return }
        
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
                // Using _ to explicitly ignore the value since we handle files through the browser's file input
                _ = openPanel.urls
                
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
    
    // Function to inject JavaScript to handle microphone permissions
    private func injectMicrophonePermissionHandlers(_ webView: WKWebView) {
        // First, check current permission status
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let statusString = currentStatus == .authorized ? "granted" : "not granted"
        
        let script = """
        (function() {
            // Store permission status and keep track of attempts
            if (!window._microphonePermissionState) {
                window._microphonePermissionState = {
                    status: '\(statusString)',
                    requestAttempts: 0,
                    lastRequestTime: null,
                    buttonsWithListeners: new Set()
                };
            }
            
            // Store active audio streams and contexts to stop them later
            if (!window.activeAudioStreams) {
                window.activeAudioStreams = [];
            }
            
            // Override getUserMedia method to check our state before requesting
            const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
            navigator.mediaDevices.getUserMedia = async function(constraints) {
                console.log('getUserMedia called with constraints:', constraints);
                
                // If audio is requested, manage permission state
                if (constraints && constraints.audio) {
                    // Don't allow rapid repeated requests
                    const now = Date.now();
                    const minTimeBetweenRequests = 5000; // 5 seconds
                    
                    if (window._microphonePermissionState.lastRequestTime && 
                        (now - window._microphonePermissionState.lastRequestTime) < minTimeBetweenRequests) {
                        console.log('Throttling permission request to prevent repeated dialogs');
                        
                        // If we've already been granted permission, proceed
                        if (window._microphonePermissionState.status === 'granted') {
                            return await originalGetUserMedia.call(this, constraints);
                        }
                        
                        // Otherwise throw an appropriate error
                        const error = new DOMException('Permission request throttled to prevent multiple dialogs', 'NotAllowedError');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionThrottled',
                            error: error.toString()
                        });
                        throw error;
                    }
                    
                    // Update state
                    window._microphonePermissionState.lastRequestTime = now;
                    window._microphonePermissionState.requestAttempts++;
                    
                    console.log('Requesting microphone permission, attempt #' + window._microphonePermissionState.requestAttempts);
                    
                    try {
                        // This will trigger the permission dialog if needed
                        const stream = await originalGetUserMedia.call(this, constraints);
                        
                        // Store the stream for later cleanup
                        window.activeAudioStreams.push(stream);
                        
                        // Add a listener to detect when the stream ends
                        stream.addEventListener('inactive', function() {
                            console.log('Audio stream became inactive');
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'streamEnded',
                                reason: 'inactive'
                            });
                            
                            // Remove this stream from active streams
                            const index = window.activeAudioStreams.indexOf(stream);
                            if (index !== -1) {
                                window.activeAudioStreams.splice(index, 1);
                            }
                        });
                        
                        // Also add listeners to all tracks
                        stream.getTracks().forEach(track => {
                            if (track.kind === 'audio') {
                                track.addEventListener('ended', function() {
                                    console.log('Audio track ended');
                                    window.webkit.messageHandlers.mediaPermission.postMessage({
                                        type: 'streamEnded',
                                        reason: 'trackEnded'
                                    });
                                    
                                    // Cleanup stream references after a track ends
                                    const index = window.activeAudioStreams.indexOf(stream);
                                    if (index !== -1) {
                                        window.activeAudioStreams.splice(index, 1);
                                    }
                                });
                            }
                        });
                        
                        // Update our state on success
                        window._microphonePermissionState.status = 'granted';
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionGranted',
                            source: 'getUserMedia'
                        });
                        
                        // Notify about voice chat activity
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'voiceChatStarted'
                        });
                        
                        return stream;
                    } catch (error) {
                        console.error('Error getting microphone access:', error);
                        
                        // Update our state on failure
                        if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                            window._microphonePermissionState.status = 'denied';
                        }
                        
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'permissionError',
                            error: error.toString(),
                            errorName: error.name
                        });
                        
                        throw error;
                    }
                }
                
                // For other requests, use the original implementation
                return await originalGetUserMedia.call(this, constraints);
            };
            
            // Add function to stop all audio tracks
            window.stopAllAudioTracks = function() {
                console.log('Stopping all audio tracks');
                
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => {
                        if (stream && typeof stream.getTracks === 'function') {
                            stream.getTracks().forEach(track => {
                                if (track.kind === 'audio') {
                                    track.stop();
                                    console.log('Stopped audio track');
                                }
                            });
                        }
                    });
                    
                    // Clear the list
                    window.activeAudioStreams = [];
                }
                
                // Close any audio contexts
                if (window.activeAudioContext) {
                    try {
                        window.activeAudioContext.close();
                        window.activeAudioContext = null;
                    } catch (e) {
                        console.error('Error closing audio context:', e);
                    }
                }
                
                return true;
            };
            
            // Also hook into any voice recognition buttons or elements
            function setupVoiceButtonListeners() {
                // Look for typical voice input buttons across different AI platforms
                const voiceSelectors = [
                    'button[aria-label*="voice"]',
                    'button[aria-label*="microphone"]',
                    'button[aria-label*="speech"]',
                    'button[aria-label*="talk"]',
                    'button[title*="voice"]',
                    'button[title*="microphone"]',
                    'button[title*="speech"]',
                    'button[title*="talk"]',
                    'button[class*="voice"]',
                    'button[class*="microphone"]',
                    'button[class*="speech"]',
                    'button[class*="talk"]',
                    'button[id*="voice"]',
                    'button[id*="microphone"]',
                    'button[id*="speech"]',
                    'button[id*="talk"]',
                    'svg[aria-label*="voice"]',
                    'svg[aria-label*="microphone"]',
                    // ChatGPT specific
                    'button[data-testid="send-button-with-voice-control"]',
                    // Add more selectors as needed for specific platforms
                ];
                
                // Try to find any voice input buttons
                for (const selector of voiceSelectors) {
                    const elements = document.querySelectorAll(selector);
                    if (elements.length > 0) {
                        elements.forEach(element => {
                            // Only add listener if it doesn't already have one and we haven't tracked it
                            if (!element.dataset.micPermissionListener && 
                                !window._microphonePermissionState.buttonsWithListeners.has(element)) {
                                
                                element.dataset.micPermissionListener = 'true';
                                window._microphonePermissionState.buttonsWithListeners.add(element);
                                
                                // Add click listener for voice start
                                element.addEventListener('click', function(e) {
                                    console.log('Voice input element clicked');
                                    
                                    // Notify native app of button click
                                    window.webkit.messageHandlers.mediaPermission.postMessage({
                                        type: 'voiceButtonClicked',
                                        selector: selector
                                    });
                                });
                            }
                        });
                    }
                }
                
                // Also look for stop buttons
                const stopSelectors = [
                    'button[aria-label*="stop"]',
                    'button[title*="stop"]',
                    'button[aria-label*="cancel"]',
                    'button[title*="cancel"]',
                    'button.cancel',
                    'button.stop'
                ];
                
                for (const selector of stopSelectors) {
                    const elements = document.querySelectorAll(selector);
                    if (elements.length > 0) {
                        elements.forEach(element => {
                            if (!element.dataset.micStopListener) {
                                element.dataset.micStopListener = 'true';
                                
                                element.addEventListener('click', function() {
                                    console.log('Voice stop button clicked');
                                    
                                    // Notify the app that voice chat stopped
                                    window.webkit.messageHandlers.mediaPermission.postMessage({
                                        type: 'voiceChatStopped',
                                        reason: 'stopButton'
                                    });
                                    
                                    // Clean up streams
                                    window.stopAllAudioTracks();
                                });
                            }
                        });
                    }
                }
            }
            
            // Run immediately
            setupVoiceButtonListeners();
            
            // Also run when DOM changes to catch dynamically added elements
            const observer = new MutationObserver(setupVoiceButtonListeners);
            observer.observe(document.body, { 
                childList: true, 
                subtree: true 
            });
            
            // Setup ESC key handler for closing voice chat
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    // Check if any voice chat UI is visible
                    const voiceUIElements = document.querySelectorAll(
                        '[aria-label="Stop recording"], [aria-label="Stop voice input"], ' +
                        '.voice-recording, .voice-input-active, .recording-active, ' +
                        '[data-voice-active="true"], [data-testid="voice-message-recording-indicator"]'
                    );
                    
                    if (voiceUIElements.length > 0) {
                        setTimeout(() => {
                            // Check if UI disappeared after ESC
                            if (document.querySelectorAll(
                                '[aria-label="Stop recording"], [aria-label="Stop voice input"], ' +
                                '.voice-recording, .voice-input-active, .recording-active, ' +
                                '[data-voice-active="true"], [data-testid="voice-message-recording-indicator"]'
                            ).length === 0) {
                                console.log('Voice UI closed with ESC key');
                                window.webkit.messageHandlers.mediaPermission.postMessage({
                                    type: 'voiceChatStopped',
                                    reason: 'escKey'
                                });
                                
                                // Clean up streams
                                window.stopAllAudioTracks();
                            }
                        }, 100);
                    }
                }
            });
            
            console.log('Enhanced microphone permission handlers successfully injected');
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting microphone permission handlers: \(error)")
            } else {
                print("Successfully injected microphone permission handlers")
                
                // Also inject a UI monitor that checks every 500ms
                self.injectVoiceChatMonitor(webView)
            }
        }
    }
    
    // Inject a monitor to check voice chat UI state every 500ms
    private func injectVoiceChatMonitor(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check if monitor is already running
            if (window._voiceChatMonitorActive) return;
            window._voiceChatMonitorActive = true;
            
            console.log('Voice chat monitor started');
            
            // Function to check voice chat UI state
            function checkVoiceChatUI() {
                // Check for voice UI elements
                const voiceUIElements = document.querySelectorAll(
                    '[aria-label="Stop recording"], [aria-label="Stop voice input"], ' +
                    '.voice-recording, .voice-input-active, .recording-active, ' + 
                    '[data-voice-active="true"], [data-testid="voice-message-recording-indicator"]'
                );
                
                if (voiceUIElements.length > 0) {
                    // Voice UI is visible
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceActivityDetected'
                    });
                }
                
                // Also check for active audio tracks
                let hasActiveAudio = false;
                if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                    for (const stream of window.activeAudioStreams) {
                        if (stream && typeof stream.getTracks === 'function') {
                            const audioTracks = stream.getTracks().filter(track => 
                                track.kind === 'audio' && track.readyState === 'live'
                            );
                            if (audioTracks.length > 0) {
                                hasActiveAudio = true;
                                break;
                            }
                        }
                    }
                }
                
                if (hasActiveAudio) {
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceActivityDetected',
                        source: 'audioTracks'
                    });
                }
                
                // Return the result
                return { hasVoiceUI: voiceUIElements.length > 0, hasActiveAudio };
            }
            
            // Set up interval to check regularly
            const monitorInterval = setInterval(checkVoiceChatUI, 500);
            
            // Clean up when page is unloaded
            window.addEventListener('beforeunload', function() {
                clearInterval(monitorInterval);
                window._voiceChatMonitorActive = false;
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting voice chat monitor: \(error)")
            } else {
                print("Successfully injected voice chat monitor")
            }
        }
    }
    
    // Add a helper method to fix permissions without triggering keychain
    private func injectPermissionFixer(_ webView: WKWebView?) {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            // Force permissions to work without additional prompts
            if (typeof navigator.mediaDevices !== 'undefined') {
                console.log('Fixing microphone permissions...');
                
                // Store original method
                const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                
                // Replace with our version that avoids additional prompts
                navigator.mediaDevices.getUserMedia = async function(constraints) {
                    console.log('Fixed getUserMedia called:', constraints);
                    try {
                        return await originalGetUserMedia.call(this, constraints);
                    } catch (error) {
                        console.error('Permission error in fixed getUserMedia:', error);
                        
                        // Special handling for audio-only constraints to avoid repeated prompts
                        if (constraints && constraints.audio && !constraints.video) {
                            // If permission was previously granted at system level but WebKit is confused,
                            // return an empty audio track to satisfy the request
                            try {
                                console.log('Creating dummy audio track to bypass permission issues');
                                const ctx = new AudioContext();
                                const oscillator = ctx.createOscillator();
                                const dst = ctx.createMediaStreamDestination();
                                oscillator.connect(dst);
                                oscillator.start();
                                const dummyTrack = dst.stream.getAudioTracks()[0];
                                dummyTrack.enabled = false; // Mute it to prevent audio feedback
                                
                                // Create a MediaStream with our dummy track
                                const stream = new MediaStream([dummyTrack]);
                                return stream;
                            } catch (fallbackError) {
                                console.error('Failed to create dummy audio track:', fallbackError);
                                throw error; // Throw the original error
                            }
                        }
                        
                        throw error; // For other cases, throw the original error
                    }
                };
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting permission fixer: \(error)")
            } else {
                print("Successfully injected permission fixer")
            }
        }
    }
    
    // Set the voice chat active state and communicate with WebViewCache
    func setVoiceChatActive(_ active: Bool) {
        // Update the voice chat active state
        isVoiceChatActive = active
        
        // If active, update the last activity time
        if active {
            lastVoiceActivityTime = Date()
        } else {
            // If setting to inactive, ensure we stop monitoring
            stopAllMicrophoneUse()
        }
    }
    
    // Monitor stream status to detect when it ends
    private func monitorStreamStatus(_ webView: WKWebView, streamInfo: [String: Any]) {
        // Add a script to monitor the status of this stream
        let script = """
        (function() {
            // Find the stream in our active streams
            const activeStream = window.activeAudioStreams && window.activeAudioStreams.length > 0 ? 
                window.activeAudioStreams[window.activeAudioStreams.length - 1] : null;
            
            if (activeStream) {
                console.log('Monitoring stream for end events');
                
                // Add listener for when stream becomes inactive
                activeStream.addEventListener('inactive', function() {
                    console.log('Stream became inactive');
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'streamEnded',
                        reason: 'inactive'
                    });
                });
                
                // Add listeners to all tracks
                activeStream.getTracks().forEach(track => {
                    track.addEventListener('ended', function() {
                        console.log('Track ended');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'streamEnded',
                            reason: 'trackEnded',
                            trackKind: track.kind
                        });
                    });
                    
                    // Also monitor muted state
                    track.addEventListener('mute', function() {
                        console.log('Track muted');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'trackMuted',
                            trackKind: track.kind
                        });
                    });
                });
                
                // Also set up a monitor for ChatGPT's voice UI
                const monitorChatGPTVoiceUI = function() {
                    // Check for recording indicator
                    const recordingIndicator = document.querySelector('[data-testid="voice-message-recording-indicator"]');
                    if (!recordingIndicator) {
                        // If indicator is gone, voice chat might have stopped
                        console.log('ChatGPT recording indicator not found, voice chat may have stopped');
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'voiceChatStopped',
                            reason: 'uiChanged'
                        });
                        return;
                    }
                    
                    // Voice is still active, send heartbeat
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceActivityDetected'
                    });
                };
                
                // Check every second for ChatGPT voice UI changes
                const monitorInterval = setInterval(monitorChatGPTVoiceUI, 1000);
                
                // Clean up interval after 60 seconds
                setTimeout(() => {
                    clearInterval(monitorInterval);
                }, 60000);
                
                return true;
            } else {
                console.log('No active stream found to monitor');
                return false;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error monitoring stream: \(error)")
            }
        }
    }
    
    // Inject script to stop all audio tracks and clean up resources
    private func injectAudioStopScript(_ webView: WKWebView) {
        let script = """
        (function() {
            console.log('Stopping all audio tracks and cleaning up audio resources');
            
            // Function to stop all tracks in a stream
            function stopAllTracks(stream) {
                if (stream && stream.getTracks) {
                    stream.getTracks().forEach(track => {
                        console.log('Stopping track:', track.kind);
                        try {
                            track.stop();
                            track.enabled = false;
                        } catch (e) {
                            console.error('Error stopping track:', e);
                        }
                    });
                }
            }
            
            // Stop any active AudioContext
            try {
                // Close all audio contexts - including any that might be created by the page
                const audioContexts = [];
                
                // Try to get audio contexts via our stored reference
                if (window.activeAudioContext) {
                    audioContexts.push(window.activeAudioContext);
                }
                
                // Also look for any global audio contexts
                if (typeof AudioContext !== 'undefined') {
                    // Try to find any other audio contexts that might be hidden in the page
                    Object.keys(window).forEach(key => {
                        try {
                            const obj = window[key];
                            if (obj instanceof AudioContext || 
                                (obj && obj.constructor && obj.constructor.name === 'AudioContext')) {
                                audioContexts.push(obj);
                            }
                        } catch (e) {}
                    });
                }
                
                // Close all found contexts
                audioContexts.forEach(ctx => {
                    try {
                        ctx.close();
                        console.log('Closed AudioContext');
                    } catch (e) {
                        console.error('Error closing AudioContext:', e);
                    }
                });
                
                window.activeAudioContext = null;
            } catch (e) {
                console.error('Error with audio contexts:', e);
            }
            
            // Stop any active oscillators
            if (window.activeOscillator) {
                try {
                    window.activeOscillator.stop();
                    console.log('Stopped active oscillator');
                } catch (e) {
                    console.error('Error stopping oscillator:', e);
                }
                window.activeOscillator = null;
            }
            
            // Clean up any stored audio streams
            if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                window.activeAudioStreams.forEach(stream => {
                    stopAllTracks(stream);
                });
                window.activeAudioStreams = [];
                console.log('Cleaned up stored audio streams');
            }
            
            // Also check for any global or stored streams
            if (window.dummyAudioStream) {
                stopAllTracks(window.dummyAudioStream);
                window.dummyAudioStream = null;
                console.log('Cleaned up dummy audio stream');
            }
            
            // Extra cleanup - look for any MediaStream objects in the global scope
            try {
                Object.keys(window).forEach(key => {
                    try {
                        const obj = window[key];
                        if (obj instanceof MediaStream || 
                            (obj && obj.constructor && obj.constructor.name === 'MediaStream')) {
                            stopAllTracks(obj);
                            console.log('Stopped additional MediaStream:', key);
                        }
                    } catch (e) {}
                });
            } catch (e) {
                console.error('Error scanning for MediaStreams:', e);
            }
            
            // Extra: Try to reset getUserMedia to prevent automatic reconnection
            if (navigator.mediaDevices && navigator._mediaDevicesGetUserMedia) {
                navigator.mediaDevices.getUserMedia = function(constraints) {
                    console.log('Blocked getUserMedia after cleanup');
                    // Return a promise that never resolves to prevent automatic reconnection
                    return new Promise((resolve, reject) => {
                        // After a very short delay, restore the original function but reject the current call
                        setTimeout(() => {
                            navigator.mediaDevices.getUserMedia = navigator._mediaDevicesGetUserMedia;
                            reject(new DOMException('Microphone access temporarily disabled', 'NotAllowedError'));
                        }, 100);
                    });
                };
                
                // Reset after 500ms to allow normal function
                setTimeout(() => {
                    if (navigator._mediaDevicesGetUserMedia) {
                        navigator.mediaDevices.getUserMedia = navigator._mediaDevicesGetUserMedia;
                    }
                }, 500);
            }
            
            // Notify app that all audio has been stopped
            if (window.webkit && window.webkit.messageHandlers && 
                window.webkit.messageHandlers.mediaPermission) {
                try {
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'audioStopped'
                    });
                } catch (e) {
                    console.error('Error sending audio stopped message:', e);
                }
            }
            
            console.log('Audio resources cleanup complete');
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error stopping audio resources: \(error)")
            } else {
                print("Successfully stopped audio resources")
            }
        }
    }
    
    private func stopAudioInCurrentWebView() {
        guard let webView = getCurrentWebView() else { return }
        
        print("Stopping audio in current WebView")
        
        // Simple script to stop all audio tracks without excessive monitoring
        let script = """
        (function() {
            console.log('Stopping microphone in web view');
            
            // Helper function to stop all tracks in a stream
            function stopTracks(stream) {
                if (stream && stream.getTracks) {
                    stream.getTracks().forEach(track => {
                        if (track.kind === 'audio') {
                            console.log('Stopping audio track');
                            track.stop();
                            track.enabled = false;
                        }
                    });
                }
            }
            
            try {
                // Stop any known active streams
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => stopTracks(stream));
                    window.activeAudioStreams = [];
                }
                
                // Clean up any AudioContext
                if (window.activeAudioContext) {
                    window.activeAudioContext.close();
                    window.activeAudioContext = null;
                }
                
                // Notify the system that audio is stopped
                if (window.webkit && window.webkit.messageHandlers && 
                    window.webkit.messageHandlers.mediaPermission) {
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'audioStopped'
                    });
                }
            } catch (e) {
                console.error('Error stopping audio:', e);
            }
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error stopping audio: \(error)")
            } else {
                print("Successfully stopped audio in WebView")
            }
        }
    }
    
    private func getCurrentWebView() -> WKWebView? {
        guard let currentServiceID = currentServiceID else { return nil }
        return webViews[currentServiceID]
    }
    
    // Make sure to set it when accessing webviews
    private func updateCurrentServiceID(for service: AIService) {
        currentServiceID = service.id.uuidString
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
    
    // Handle all key down events and prevent unexpected app quitting
    override func keyDown(with event: NSEvent) {
        // Allow only specific command key combinations to pass through
        if event.modifierFlags.contains(.command) {
            // Handle Command+E (toggle window) at the application level
            if event.keyCode == 0x0E { // E key
                // Skip this as it's handled by the global shortcut monitor
                super.keyDown(with: event)
                return
            }
            
            // Handle standard shortcuts (copy, paste, select all)
            let allowedShortcuts: [UInt16] = [
                0x00, // A - Select All
                0x08, // C - Copy
                0x09, // V - Paste
            ]
            
            if allowedShortcuts.contains(event.keyCode) {
                if handleStandardShortcut(event) {
                    return
                }
            }
        }
        
        // Check if the webView is the current first responder or its child is
        if isWebViewOrChildFirstResponder() {
            // If the webView or its child has focus, pass all keyboard events to it
            if let webView = webView {
                webView.keyDown(with: event)
            } else {
                super.keyDown(with: event)
            }
        } else {
            // If webView doesn't have focus, only close the window (never quit the app)
            closePopupWindowSafely()
            
            // Consume the event to prevent it from propagating further
            return
        }
    }
    
    // Handle key equivalents (keyboard shortcuts)
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Always allow Command+E (toggle window) - handled at app level
        if event.modifierFlags.contains(.command) && event.keyCode == 0x0E {
            return super.performKeyEquivalent(with: event)
        }
        
        // Allow only specific command key combinations
        if event.modifierFlags.contains(.command) {
            let allowedShortcuts: [UInt16] = [
                0x00, // A - Select All
                0x08, // C - Copy
                0x09, // V - Paste
            ]
            
            if allowedShortcuts.contains(event.keyCode) {
                if handleStandardShortcut(event) {
                    return true
                }
            }
        }
        
        // Check if the webView is the current first responder or its child is
        if isWebViewOrChildFirstResponder() {
            // If the webView or its child has focus, pass key equivalents to it
            if let webView = webView {
                return webView.performKeyEquivalent(with: event)
            }
        }
        
        // For all other key combinations, only close the window (never quit the app)
        closePopupWindowSafely()
        
        // Return true to indicate we've handled the event and prevent it from propagating
        return true
    }
    
    // Safely close the popup window without app quitting
    private func closePopupWindowSafely() {
        if let appDelegate = NSApp.delegate as? AppDelegate, let menuBarManager = appDelegate.menuBarManager {
            DispatchQueue.main.async {
                menuBarManager.perform(#selector(MenuBarManager.togglePopupWindow))
            }
        } else {
            // Fallback if we can't find the menuBarManager - just hide the window
            if let window = self.window {
                DispatchQueue.main.async {
                    window.orderOut(nil)
                }
            }
        }
    }
    
    // Helper method to handle standard keyboard shortcuts
    private func handleStandardShortcut(_ event: NSEvent) -> Bool {
        guard let webView = webView else { return false }
        
        // Keyboard shortcuts map
        let shortcuts: [UInt16: Selector] = [
            0x00: #selector(NSText.selectAll(_:)),          // A - Select All
            0x08: #selector(NSText.copy(_:)),               // C - Copy
            0x09: #selector(NSText.paste(_:)),              // V - Paste
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
            default:
                break
            }
        }
        
        return false
    }
    
    // Helper method to check if the webView or its child is the first responder
    private func isWebViewOrChildFirstResponder() -> Bool {
        guard let window = self.window, let webView = self.webView else {
            return false
        }
        
        // Get the current first responder
        guard let firstResponder = window.firstResponder else {
            return false
        }
        
        // Check if the first responder is the webView or a child of it
        if firstResponder === webView {
            return true
        }
        
        // Check if the first responder is a descendant of the webView
        var responder: NSResponder? = firstResponder
        while let nextResponder = responder?.nextResponder {
            if nextResponder === webView {
                return true
            }
            responder = nextResponder
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
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
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
        isLoading = WebViewCache.shared.loadingStates[service.id.uuidString] ?? true
        
        // Focus the current webview
        focusCurrentWebView(in: containerView)
        
        // Add notification observer for window focus changes
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            if let window = notification.object as? NSWindow, 
               window.contentView?.isDescendant(of: containerView) == true {
                // When window becomes key, focus the webview
                focusCurrentWebView(in: containerView)
            }
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update loading status
        isLoading = WebViewCache.shared.loadingStates[service.id.uuidString] ?? true
        
        // Show only the selected webview, hide all others
        var didUpdateVisibility = false
        for subview in nsView.subviews {
            if let responderView = subview as? KeyboardResponderView {
                // Find which service this responder's webview belongs to
                if let webView = responderView.webView {
                    for cachedService in aiServices {
                        if webView === WebViewCache.shared.getWebView(for: cachedService) {
                            // Check if we're changing visibility
                            let shouldBeVisible = cachedService.id == service.id
                            if responderView.isHidden == shouldBeVisible {
                                didUpdateVisibility = true
                            }
                            // Set visibility based on whether this is the selected service
                            responderView.isHidden = !shouldBeVisible
                        }
                    }
                }
            }
        }
        
        // Focus the current webview, with added delays if we just changed visibility
        if didUpdateVisibility {
            // Multiple attempts with increasing delays to handle race conditions
            let delays: [TimeInterval] = [0.1, 0.3, 0.6, 1.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    focusCurrentWebView(in: nsView)
                }
            }
        } else {
            // Single attempt if we didn't change visibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusCurrentWebView(in: nsView)
            }
        }
    }
    
    private func focusCurrentWebView(in containerView: NSView) {
        // Get the window containing the container view
        guard let window = containerView.window else { return }
        
        var foundResponder = false
        var foundWebView: NSView? = nil
        
        // Try to find the visible KeyboardResponderView first
        for subview in containerView.subviews where !subview.isHidden {
            if let responderView = subview as? KeyboardResponderView {
                // Make the responder view the first responder
                window.makeFirstResponder(responderView)
                foundResponder = true
                break
            }
        }
        
        // If we couldn't find a responder view, try to find the visible WKWebView
        if !foundResponder {
            // Recursive function to find WKWebView in the view hierarchy
            func findWebView(in view: NSView) -> NSView? {
                if NSStringFromClass(type(of: view)).contains("WKWebView") {
                    return view
                }
                
                for subview in view.subviews where !subview.isHidden {
                    if let webView = findWebView(in: subview) {
                        return webView
                    }
                }
                
                return nil
            }
            
            // Find the visible WKWebView
            foundWebView = findWebView(in: containerView)
            
            // Make it first responder if found
            if let webView = foundWebView {
                window.makeFirstResponder(webView)
            }
        }
        
        // If all else fails, try to get the webview directly from the cache
        if !foundResponder && foundWebView == nil {
            let webView = WebViewCache.shared.getWebView(for: service)
            window.makeFirstResponder(webView)
            
            // Forcefully inject focus into the webview using JavaScript (last resort)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let focusScript = """
                (function() {
                    // Try to focus any input field
                    var inputs = document.querySelectorAll('input, textarea, [contenteditable="true"]');
                    if (inputs.length > 0) {
                        inputs[0].focus();
                        return true;
                    }
                    
                    // If no input found, try to click on the document body
                    if (document.body) {
                        document.body.click();
                        return true;
                    }
                    
                    return false;
                })();
                """
                
                webView.evaluateJavaScript(focusScript) { (result, error) in
                    if let error = error {
                        print("Error focusing webview: \(error)")
                    }
                }
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
        isLoading = WebViewCache.shared.loadingStates[service.id.uuidString] ?? true
        
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
                    isLoading = WebViewCache.shared.loadingStates[newService.id.uuidString] ?? true
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