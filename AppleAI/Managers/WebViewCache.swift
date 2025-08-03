import SwiftUI
import WebKit
import AVFoundation

class WebViewCache: ObservableObject {
    static let shared = WebViewCache()
    
    @Published private var webViews: [String: WKWebView] = [:]
    @Published private var loadingStates: [String: Bool] = [:]
    private var coordinators: [String: WebViewCoordinator] = [:]
    
    // Create a shared process pool for all WebViews
    private static let sharedProcessPool = WKProcessPool()
    
    // Track whether voice chat is actively being used
    private var isUsingVoiceChat: Bool = false
    
    // Store the timestamp of the last voice chat activity
    private var lastVoiceChatActivityTime: Date?
    
    // Service-specific tracking
    private var activeVoiceChatServices: Set<String> = []
    
    private init() {
        // In demo version, we don't initialize any real functionality
        // All web views will be created on-demand with limited capabilities
        
        // Set up a placeholder for demo purposes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDemoModeAlert),
            name: .init("DemoModeAlert"),
            object: nil
        )
    }
    
    @objc private func showDemoModeAlert() {
        // This would show a demo mode alert in the UI
        print("Running in demo mode - full functionality not available")
    }
    
    deinit {
        // REMOVED: We don't need to stop the timer since we're not using it
        // stopMicrophoneMonitorTimer()
    }
    
    // Track voice chat usage state - simplified version
    func setVoiceChatActive(_ active: Bool) {
        let wasActive = isUsingVoiceChat
        isUsingVoiceChat = active
        
        // Update last activity time
        if active {
            lastVoiceChatActivityTime = Date()
            
            // When voice chat becomes active, inject the monitoring script to detect when it's closed
            for webView in webViews.values {
                injectVoiceChatCloseDetector(webView)
            }
        }
        
        // Log state change
        if wasActive != active {
            print("Voice chat active: \(active)")
        }
        
        // If no longer active, ensure we clean up audio resources after a delay
        if !active && wasActive {
            // Stop audio after a short delay to allow for quick reconnections
            // Using a longer delay to reduce CPU usage from rapid start/stop
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, !self.isUsingVoiceChat else { return }
                self.stopAllMicrophoneUse()
            }
        }
    }
    
    // Public method to check if voice chat is active
    func isVoiceChatActive() -> Bool {
        // If we had activity recently, consider it active
        if let lastActivity = lastVoiceChatActivityTime,
           Date().timeIntervalSince(lastActivity) < 3.0 {
            return true
        }
        return isUsingVoiceChat
    }
    
    // Execute a closure on all web views - useful for global operations
    func performInAllWebViews(_ operation: (WKWebView) -> Void) {
        for webView in webViews.values {
            operation(webView)
        }
    }
    
    // Inject a script to detect when voice chat is closed through UI interactions
    private func injectVoiceChatCloseDetector(_ webView: WKWebView) {
        // Check if this is for Copilot to use an enhanced version
        let isCopilot = webView.url?.host?.contains("copilot.microsoft.com") ?? false
        
        // Use a more aggressive script for Copilot
        let script = isCopilot ? copilotVoiceChatDetectorScript() : standardVoiceChatDetectorScript()
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting voice chat close detector: \(error)")
            } else {
                print("Successfully injected voice chat close detector")
                
                // For Copilot, inject an extra aggressive audio cleanup script that runs periodically
                if isCopilot {
                    self.injectCopilotAudioCleanupScript(webView)
                }
            }
        }
    }
    
    // Standard voice chat detector script for most services
    private func standardVoiceChatDetectorScript() -> String {
        return """
        (function() {
            // Check if detector is already running
            if (window._voiceChatCloseDetectorActive) return;
            window._voiceChatCloseDetectorActive = true;
            
            console.log('Voice chat close detector activated');
            
            // Function to check if voice chat UI is visible
            function isVoiceChatUIVisible() {
                // ChatGPT voice chat elements
                const chatGPTElements = document.querySelectorAll('[aria-label="Stop recording"], [aria-label="Voice input enabled"], .voice-input-active, .recording-button-active');
                
                // Microsoft Copilot voice elements
                const copilotElements = document.querySelectorAll('[aria-label="Stop voice input"], .voice-input-container:not(.hidden), [data-testid="voice-input-button"].active');
                
                // Generic voice UI elements
                const genericElements = document.querySelectorAll('.voice-recording, .microphone-active, .recording-active, [data-voice-active="true"]');
                
                return chatGPTElements.length > 0 || copilotElements.length > 0 || genericElements.length > 0;
            }
            
            // Keep track of previous voice UI state
            let wasVoiceChatVisible = isVoiceChatUIVisible();
            
            // Setup observer for "Stop" or "X" button clicks
            const clickObserver = new MutationObserver(() => {
                // Look for stop/close buttons in voice chat UI
                const stopButtons = document.querySelectorAll(
                    '[aria-label="Stop recording"], [aria-label="Stop voice input"], .voice-stop-button, .close-voice-button, ' +
                    'button.voice-close, [data-testid="voice-stop-button"], [aria-label="Stop listening"]'
                );
                
                // Add click listeners to stop buttons if found
                stopButtons.forEach(button => {
                    if (!button._hasVoiceStopListener) {
                        button._hasVoiceStopListener = true;
                        button.addEventListener('click', () => {
                            console.log('Voice chat stop button clicked');
                            // Notify Swift that voice chat was explicitly stopped
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStopped',
                                reason: 'userClosed'
                            });
                            
                            // Force stop any active audio
                            if (window.activeAudioStreams) {
                                window.activeAudioStreams.forEach(stream => {
                                    if (stream && typeof stream.getTracks === 'function') {
                                        stream.getTracks().forEach(track => {
                                            if (track.kind === 'audio') {
                                                console.log('Explicitly stopping audio track after close button');
                                                track.stop();
                                            }
                                        });
                                    }
                                });
                            }
                        });
                    }
                });
            });
            
            // Start observing for stop buttons
            clickObserver.observe(document.body, { 
                childList: true, 
                subtree: true,
                attributes: true, 
                attributeFilter: ['class', 'aria-label', 'data-testid'] 
            });
            
            // Setup periodic check for voice UI disappearing (every 500ms)
            const voiceUICheckInterval = setInterval(() => {
                const isVoiceChatVisible = isVoiceChatUIVisible();
                
                // If voice chat was visible and now it's not, report it as closed
                if (wasVoiceChatVisible && !isVoiceChatVisible) {
                    console.log('Voice chat UI disappeared - voice chat closed');
                    
                    // Notify Swift that voice chat UI was closed
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceChatStopped',
                        reason: 'uiClosed'
                    });
                    
                    // Force stop any active audio streams
                    if (window.activeAudioStreams) {
                        window.activeAudioStreams.forEach(stream => {
                            if (stream && typeof stream.getTracks === 'function') {
                                stream.getTracks().forEach(track => {
                                    if (track.kind === 'audio') {
                                        console.log('Stopping audio track after UI closed');
                                        track.stop();
                                    }
                                });
                            }
                        });
                    }
                }
                
                // If voice chat UI has appeared, report it
                if (!wasVoiceChatVisible && isVoiceChatVisible) {
                    console.log('Voice chat UI appeared - voice chat active');
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceChatStarted',
                        reason: 'uiDetected'
                    });
                }
                
                // Update previous state
                wasVoiceChatVisible = isVoiceChatVisible;
            }, 500);
            
            // Also track ESC key as it's often used to close voice dialog
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape' && wasVoiceChatVisible) {
                    console.log('ESC key pressed while voice chat was active');
                    
                    // Check after a small delay if voice UI disappeared
                    setTimeout(() => {
                        if (!isVoiceChatUIVisible()) {
                            console.log('Voice chat closed by ESC key');
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStopped',
                                reason: 'escKey'
                            });
                        }
                    }, 100);
                }
            });
            
            // Clean up resources if the window or tab is closed
            window.addEventListener('beforeunload', () => {
                clearInterval(voiceUICheckInterval);
                clickObserver.disconnect();
                console.log('Voice chat detector cleaned up');
            });
        })();
        """
    }
    
    // Enhanced voice chat detector specifically for Microsoft Copilot
    private func copilotVoiceChatDetectorScript() -> String {
        return """
        (function() {
            // Check if detector is already running
            if (window._copilotVoiceChatCloseDetectorActive) return;
            window._copilotVoiceChatCloseDetectorActive = true;
            
            console.log('Copilot voice chat detector activated');
            
            // Function to check if voice chat UI is visible in Copilot
            function isVoiceChatUIVisible() {
                // Primary Microsoft Copilot voice elements (most common)
                const primaryElements = document.querySelectorAll(
                    '[aria-label="Stop voice input"], ' + 
                    '.voice-input-container:not(.hidden), ' + 
                    '[data-testid="voice-input-button"].active, ' +
                    '.voice-input-active, ' +
                    '.sydney-voice-input'
                );
                
                // Secondary Microsoft Copilot indicators (less common)
                const secondaryElements = document.querySelectorAll(
                    '[aria-label="Voice input in progress"], ' +
                    '[aria-label="Listening..."], ' +
                    '[aria-label="Recording in progress"], ' +
                    '.voice-active, ' +
                    '.microphone-pulse, ' +
                    '.listening-animation, ' +
                    '.voice-typing-indicator'
                );
                
                // Check for any voice animation elements or container elements
                const animationElements = document.querySelectorAll(
                    '.voice-animation, ' +
                    '.voice-wave, ' +
                    '.voice-pulse, ' +
                    '.microphone-animation-container, ' +
                    '[data-recording="true"]'
                );
                
                // Look for the voice input button with active state through various ways
                const voiceButtons = document.querySelectorAll('button[aria-pressed="true"][aria-label*="voice"], button.active[aria-label*="voice"]');
                
                return primaryElements.length > 0 || secondaryElements.length > 0 || animationElements.length > 0 || voiceButtons.length > 0;
            }
            
            // Keep track of previous voice UI state
            let wasVoiceChatVisible = isVoiceChatUIVisible();
            
            // Setup observer for voice elements and changes - very broad to catch everything
            const observer = new MutationObserver(() => {
                // Re-check voice UI visibility
                const isVoiceChatVisible = isVoiceChatUIVisible();
                
                // Look for stop/close buttons in voice chat UI
                const stopButtons = document.querySelectorAll(
                    '[aria-label="Stop voice input"], ' +
                    '[aria-label="Stop recording"], ' +
                    '[aria-label="Stop listening"], ' +
                    'button[aria-label*="stop"], ' +
                    'button.voice-stop-button, ' +
                    'button.voice-cancel, ' +
                    'button.close-voice-button, ' +
                    'button.voice-close'
                );
                
                // Add click listeners to stop buttons if found
                stopButtons.forEach(button => {
                    if (!button._hasVoiceStopListener) {
                        button._hasVoiceStopListener = true;
                        button.addEventListener('click', () => {
                            console.log('Copilot voice chat stop button clicked');
                            // Notify Swift that voice chat was explicitly stopped
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStopped',
                                reason: 'userClosed',
                                service: 'copilot'
                            });
                            
                            // Force stop any active audio
                            stopAllAudioResources();
                        });
                    }
                });
                
                // If voice chat was visible and now it's not
                if (wasVoiceChatVisible && !isVoiceChatVisible) {
                    console.log('Copilot voice chat UI disappeared');
                    
                    // Notify Swift that voice chat was closed
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceChatStopped',
                        reason: 'uiClosed',
                        service: 'copilot'
                    });
                    
                    // Force stop any active audio immediately
                    stopAllAudioResources();
                }
                
                // If voice chat newly appeared
                if (!wasVoiceChatVisible && isVoiceChatVisible) {
                    console.log('Copilot voice chat UI appeared');
                    
                    // Notify Swift that voice chat started
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceChatStarted',
                        reason: 'uiDetected',
                        service: 'copilot'
                    });
                }
                
                // Update previous state
                wasVoiceChatVisible = isVoiceChatVisible;
            });
            
            // Very aggressive helper function to stop all audio resources
            function stopAllAudioResources() {
                console.log('Stopping all Copilot audio resources');
                
                try {
                    // Stop all audio tracks in all streams
                    if (window.activeAudioStreams) {
                        window.activeAudioStreams.forEach(stream => {
                            if (stream && typeof stream.getTracks === 'function') {
                                stream.getTracks().forEach(track => {
                                    if (track.kind === 'audio') {
                                        console.log('Stopping Copilot audio track');
                                        track.stop();
                                        track.enabled = false;
                                    }
                                });
                            }
                        });
                        
                        // Clear active streams
                        window.activeAudioStreams = [];
                    }
                    
                    // Also find and stop any active audio contexts
                    if (window.activeAudioContext) {
                        try {
                            window.activeAudioContext.close();
                            window.activeAudioContext = null;
                        } catch (e) {
                            console.error('Error closing audio context:', e);
                        }
                    }
                    
                    // Additional cleanup for any global MediaRecorder instances
                    if (window.activeMediaRecorder) {
                        try {
                            window.activeMediaRecorder.stop();
                            window.activeMediaRecorder = null;
                        } catch (e) {
                            console.error('Error stopping media recorder:', e);
                        }
                    }
                    
                    // Microsoft Copilot may use the SpeechRecognition API
                    if (window.SpeechRecognition || window.webkitSpeechRecognition) {
                        // Try to find any active recognition and stop it
                        if (window.activeSpeechRecognition) {
                            try {
                                window.activeSpeechRecognition.stop();
                                window.activeSpeechRecognition.abort();
                                window.activeSpeechRecognition = null;
                            } catch (e) {
                                console.error('Error stopping speech recognition:', e);
                            }
                        }
                    }
                    
                    console.log('Successfully stopped all Copilot audio resources');
                } catch (e) {
                    console.error('Error in stopAllAudioResources:', e);
                }
            }
            
            // Start observing the entire document for changes
            observer.observe(document.body, { 
                childList: true, 
                subtree: true, 
                attributes: true, 
                characterData: true,
                attributeFilter: ['class', 'style', 'aria-label', 'aria-pressed', 'data-recording', 'data-testid'] 
            });
            
            // Set up a more frequent check (every 300ms) specifically for Copilot
            const checkInterval = setInterval(() => {
                // Force re-check UI visibility
                const isVoiceChatVisible = isVoiceChatUIVisible();
                
                // Update state if needed
                if (wasVoiceChatVisible !== isVoiceChatVisible) {
                    if (wasVoiceChatVisible && !isVoiceChatVisible) {
                        // Voice chat disappeared since last check
                        console.log('Copilot voice chat UI disappeared (interval check)');
                        
                        // Notify Swift
                        window.webkit.messageHandlers.mediaPermission.postMessage({
                            type: 'voiceChatStopped',
                            reason: 'intervalCheck',
                            service: 'copilot'
                        });
                        
                        // Force stop audio
                        stopAllAudioResources();
                    }
                    
                    // Update state
                    wasVoiceChatVisible = isVoiceChatVisible;
                }
                
                // Also perform a direct check of audio tracks
                checkForActiveAudio();
            }, 300);
            
            // Function to directly check for active audio tracks
            function checkForActiveAudio() {
                let hasActiveAudio = false;
                
                if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                    for (const stream of window.activeAudioStreams) {
                        if (stream && typeof stream.getAudioTracks === 'function') {
                            const audioTracks = stream.getAudioTracks();
                            if (audioTracks.some(track => track.readyState === 'live' && track.enabled)) {
                                hasActiveAudio = true;
                                break;
                            }
                        }
                    }
                }
                
                // If we have active audio but no visible UI, we need to stop it
                if (hasActiveAudio && !isVoiceChatUIVisible()) {
                    console.log('Found active audio without visible UI - stopping');
                    stopAllAudioResources();
                    
                    // Notify Swift
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'voiceChatStopped',
                        reason: 'hiddenAudioDetected',
                        service: 'copilot'
                    });
                }
            }
            
            // Override getUserMedia to track when it's called by Copilot
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                
                navigator.mediaDevices.getUserMedia = async function(constraints) {
                    console.log('Copilot called getUserMedia with:', constraints);
                    
                    try {
                        const stream = await originalGetUserMedia.call(this, constraints);
                        
                        // If this has audio, consider it voice chat
                        if (constraints && constraints.audio) {
                            console.log('Copilot requested audio - voice chat started');
                            
                            // Notify Swift
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStarted',
                                reason: 'getUserMedia',
                                service: 'copilot'
                            });
                            
                            // Store stream for tracking
                            if (!window.activeAudioStreams) {
                                window.activeAudioStreams = [];
                            }
                            window.activeAudioStreams.push(stream);
                            
                            // Add listeners for stream and track ended events
                            stream.addEventListener('inactive', () => {
                                console.log('Copilot audio stream inactive');
                                window.webkit.messageHandlers.mediaPermission.postMessage({
                                    type: 'streamEnded',
                                    reason: 'streamInactive',
                                    service: 'copilot'
                                });
                            });
                            
                            stream.getTracks().forEach(track => {
                                if (track.kind === 'audio') {
                                    track.addEventListener('ended', () => {
                                        console.log('Copilot audio track ended');
                                        window.webkit.messageHandlers.mediaPermission.postMessage({
                                            type: 'streamEnded',
                                            reason: 'trackEnded',
                                            service: 'copilot'
                                        });
                                    });
                                }
                            });
                        }
                        
                        return stream;
                    } catch (err) {
                        console.error('Copilot getUserMedia error:', err);
                        throw err;
                    }
                };
            }
            
            // Also handle ESC key specifically for Copilot
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape' && wasVoiceChatVisible) {
                    console.log('ESC key pressed while Copilot voice chat active');
                    
                    // Check after a small delay if voice UI disappeared
                    setTimeout(() => {
                        if (!isVoiceChatUIVisible()) {
                            console.log('Copilot voice chat closed by ESC key');
                            
                            // Notify Swift
                            window.webkit.messageHandlers.mediaPermission.postMessage({
                                type: 'voiceChatStopped',
                                reason: 'escKey',
                                service: 'copilot'
                            });
                            
                            // Force stop audio
                            stopAllAudioResources();
                        }
                    }, 100);
                }
            });
            
            // Clean up when the page is closed
            window.addEventListener('beforeunload', () => {
                clearInterval(checkInterval);
                observer.disconnect();
                stopAllAudioResources();
                console.log('Copilot voice chat detector cleaned up');
            });
            
            console.log('Copilot voice chat detector ready');
        })();
        """
    }
    
    // Add a specialized Copilot audio cleanup script that runs periodically
    private func injectCopilotAudioCleanupScript(_ webView: WKWebView) {
        let script = """
        (function() {
            // Check if already running
            if (window._copilotAudioCleanupActive) return;
            window._copilotAudioCleanupActive = true;
            
            console.log('Copilot audio cleanup monitor activated');
            
            // Function to determine if voice chat UI is currently active
            function isVoiceActive() {
                // Look for specific Copilot voice UI elements
                const voiceElements = document.querySelectorAll(
                    '[aria-label="Stop voice input"], ' +
                    '.voice-input-container:not(.hidden), ' +
                    '[data-testid="voice-input-button"].active, ' +
                    '.voice-input-active, ' +
                    '.sydney-voice-input, ' +
                    '[aria-label="Voice input in progress"], ' +
                    '[aria-label="Listening..."], ' +
                    '.voice-active, ' +
                    '.microphone-pulse'
                );
                
                return voiceElements.length > 0;
            }
            
            // Function to forcefully stop all audio
            function forceStopAllAudio() {
                console.log('Force stopping all audio in Copilot');
                
                try {
                    // 1. Stop all MediaStream tracks
                    if (window.activeAudioStreams) {
                        window.activeAudioStreams.forEach(stream => {
                            if (stream && typeof stream.getTracks === 'function') {
                                stream.getTracks().forEach(track => {
                                    if (track.kind === 'audio') {
                                        track.stop();
                                        track.enabled = false;
                                    }
                                });
                            }
                        });
                        window.activeAudioStreams = [];
                    }
                    
                    // 2. Find all audio elements and mute/pause them
                    document.querySelectorAll('audio').forEach(audio => {
                        audio.pause();
                        audio.srcObject = null;
                    });
                    
                    // 3. Look for and close any audio contexts
                    if (window.activeAudioContext) {
                        try { 
                            window.activeAudioContext.close();
                            window.activeAudioContext = null;
                        } catch (e) {}
                    }
                    
                    // 4. Microsoft Copilot specific: try to find and stop speech recognition
                    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
                    if (SpeechRecognition && window.activeSpeechRecognition) {
                        try {
                            window.activeSpeechRecognition.stop();
                            window.activeSpeechRecognition.abort();
                            window.activeSpeechRecognition = null;
                        } catch (e) {}
                    }
                    
                    // 5. For Copilot which may use MediaRecorder
                    if (window.activeMediaRecorder) {
                        try {
                            window.activeMediaRecorder.stop();
                            window.activeMediaRecorder = null;
                        } catch (e) {}
                    }
                    
                    // 6. Try to find active recording indicators and click their close buttons
                    document.querySelectorAll('[aria-label="Stop voice input"], [aria-label="Stop recording"]').forEach(button => {
                        try {
                            button.click();
                        } catch (e) {}
                    });
                    
                    // Report to Swift that we've stopped audio
                    window.webkit.messageHandlers.mediaPermission.postMessage({
                        type: 'forcedAudioStop',
                        service: 'copilot'
                    });
                    
                    console.log('Copilot audio resources forcefully stopped');
                } catch (e) {
                    console.error('Error force stopping audio:', e);
                }
            }
            
            // Track voice activity state
            let lastVoiceActiveState = isVoiceActive();
            let lastActiveTime = Date.now();
            
            // Set up a monitor that runs every 250ms
            const monitorInterval = setInterval(() => {
                const currentlyActive = isVoiceActive();
                
                // If voice was active but now isn't
                if (lastVoiceActiveState && !currentlyActive) {
                    console.log('Voice activity ended in Copilot');
                    
                    // Force stop audio with a slight delay to allow for any cleanup
                    setTimeout(forceStopAllAudio, 500);
                    
                    // Update last active time
                    lastActiveTime = Date.now();
                }
                
                // If voice is currently active, update timestamp
                if (currentlyActive) {
                    lastActiveTime = Date.now();
                }
                // If voice has been inactive for more than 2 seconds, do an extra cleanup
                else if (Date.now() - lastActiveTime > 2000) {
                    // Check directly for any active audio
                    let hasActiveAudio = false;
                    
                    // Look for active audio tracks
                    if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                        for (const stream of window.activeAudioStreams) {
                            if (stream && typeof stream.getAudioTracks === 'function') {
                                const audioTracks = stream.getAudioTracks();
                                if (audioTracks.some(track => track.readyState === 'live')) {
                                    hasActiveAudio = true;
                                    break;
                                }
                            }
                        }
                    }
                    
                    // If we still have active audio but UI is not visible, force stop
                    if (hasActiveAudio) {
                        console.log('Found active audio without visible UI in Copilot - forcing stop');
                        forceStopAllAudio();
                    }
                }
                
                // Update previous state
                lastVoiceActiveState = currentlyActive;
            }, 250);
            
            // Clean up on page unload
            window.addEventListener('beforeunload', () => {
                clearInterval(monitorInterval);
                forceStopAllAudio();
                window._copilotAudioCleanupActive = false;
                console.log('Copilot audio cleanup monitor stopped');
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting Copilot audio cleanup: \(error)")
            } else {
                print("Successfully injected Copilot audio cleanup")
            }
        }
    }
    
    // Function to stop all microphone use - simplified version to be less resource intensive
    func stopAllMicrophoneUse() {
        print("Stopping all microphone use")
        
        // Reset voice chat state
        isUsingVoiceChat = false
        lastVoiceChatActivityTime = nil
        activeVoiceChatServices.removeAll()
        
        // Stop any active audio in all webviews using a simpler, more efficient approach
        for webView in webViews.values {
            // Check if this is a Copilot webview
            let isCopilot = webView.url?.host?.contains("copilot.microsoft.com") ?? false
            
            if isCopilot {
                // Use an enhanced script for Copilot
                injectCopilotForceStopScript(webView)
            } else {
                // Use the regular script for other services
                injectSimpleAudioStopScript(webView)
            }
        }
    }
    
    // Special forceful script to stop Copilot microphone use
    private func injectCopilotForceStopScript(_ webView: WKWebView) {
        let script = """
        (function() {
            console.log('Forcefully stopping Copilot microphone use');
            
            // Most aggressive approach to stop all audio in Copilot
            try {
                // 1. Stop all MediaStream tracks
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => {
                        if (stream && typeof stream.getTracks === 'function') {
                            stream.getTracks().forEach(track => {
                                if (track.kind === 'audio') {
                                    console.log('Stopping Copilot audio track');
                                    track.stop();
                                    track.enabled = false;
                                }
                            });
                        }
                    });
                    window.activeAudioStreams = [];
                }
                
                // 2. Find any MediaRecorder instances
                if (window.activeMediaRecorder) {
                    try {
                        window.activeMediaRecorder.stop();
                        window.activeMediaRecorder = null;
                    } catch (e) {}
                }
                
                // 3. Close any AudioContext instances
                if (window.activeAudioContext) {
                    try {
                        window.activeAudioContext.close();
                        window.activeAudioContext = null;
                    } catch (e) {}
                }
                
                // 4. Stop any speech recognition
                const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
                if (SpeechRecognition && window.activeSpeechRecognition) {
                    try {
                        window.activeSpeechRecognition.stop();
                        window.activeSpeechRecognition.abort();
                        window.activeSpeechRecognition = null;
                    } catch (e) {}
                }
                
                // 5. Try to find and click any stop buttons
                const stopButtons = document.querySelectorAll(
                    '[aria-label="Stop voice input"], ' + 
                    '[aria-label="Stop recording"], ' +
                    '.voice-stop-button, ' +
                    '.close-voice-button, ' +
                    'button.voice-close'
                );
                
                stopButtons.forEach(button => {
                    try {
                        console.log('Clicking Copilot stop button');
                        button.click();
                    } catch (e) {}
                });
                
                // 6. Find all voice input elements and modify their state
                const voiceElements = document.querySelectorAll(
                    '.voice-input-container:not(.hidden), ' +
                    '[data-testid="voice-input-button"].active, ' +
                    '.voice-input-active, ' +
                    '.sydney-voice-input'
                );
                
                voiceElements.forEach(element => {
                    try {
                        // Try to hide or remove the element
                        element.classList.add('hidden');
                        element.style.display = 'none';
                    } catch (e) {}
                });
                
                // 7. Directly patch getUserMedia to block further audio requests
                if (navigator.mediaDevices && !window._getUserMediaPatched) {
                    window._getUserMediaPatched = true;
                    const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                    
                    // Add a temporary block (lasts 5 seconds)
                    navigator.mediaDevices.getUserMedia = async function(constraints) {
                        if (constraints && constraints.audio) {
                            console.log('Temporarily blocking Copilot audio request');
                            
                            // Remove audio from constraints
                            const newConstraints = {...constraints};
                            delete newConstraints.audio;
                            
                            // If video is requested, continue with just video
                            if (newConstraints.video) {
                                return await originalGetUserMedia.call(this, newConstraints);
                            }
                            
                            // Otherwise, reject with NotAllowedError (same as user denial)
                            return Promise.reject(new DOMException('Permission denied by force stop script', 'NotAllowedError'));
                        }
                        
                        // Non-audio requests pass through
                        return await originalGetUserMedia.call(this, constraints);
                    };
                    
                    // Restore normal function after 5 seconds
                    setTimeout(() => {
                        if (window._getUserMediaPatched) {
                            navigator.mediaDevices.getUserMedia = originalGetUserMedia;
                            window._getUserMediaPatched = false;
                            console.log('Restored normal getUserMedia function');
                        }
                    }, 5000);
                }
                
                console.log('Successfully stopped all Copilot audio');
                return true;
            } catch (e) {
                console.error('Error stopping Copilot audio:', e);
                return false;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error stopping Copilot audio: \(error)")
            } else if let success = result as? Bool, success {
                print("Successfully stopped all Copilot audio")
            } else {
                print("Attempted to stop Copilot audio with unknown result")
            }
        }
    }
    
    // Inject a simpler script that's less resource intensive
    private func injectSimpleAudioStopScript(_ webView: WKWebView) {
        let script = """
        (function() {
            console.log('Stopping microphone use');
            
            // Function to stop all tracks in a stream
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
                // Stop any active audio streams
                if (window.activeAudioStreams) {
                    window.activeAudioStreams.forEach(stream => stopTracks(stream));
                    window.activeAudioStreams = [];
                }
                
                // Close audio context if one exists
                if (window.activeAudioContext) {
                    window.activeAudioContext.close();
                    window.activeAudioContext = null;
                }
                
                // Stop any active oscillator
                if (window.activeOscillator) {
                    window.activeOscillator.stop();
                    window.activeOscillator = null;
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
                print("Successfully stopped audio")
            }
        }
    }
    
    // Function to completely disable persistent storage for WebKit
    private func disablePersistentStorageForWebKit() {
        // Clear all website data to start fresh
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { }
        
        // Set Safari defaults to never store credentials
        UserDefaults.standard.set(false, forKey: "WebKitStorageBlockingPolicy")
        UserDefaults.standard.set(false, forKey: "WebKitStorageBlockingPolicy")
        UserDefaults.standard.set(false, forKey: "WebKitCredentialStorageEnabled")
        UserDefaults.standard.set(false, forKey: "WebKitAuthorAndUserStylesEnabled")
    }
    
    // Set up observers for app state to manage microphone resources
    private func setupAppStateObservers() {
        // Listen for when the app becomes inactive
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Stop microphone when app is no longer in focus
            self?.stopAllMicrophoneUse()
        }
        
        // Also observe when the window becomes inactive
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Stop microphone when window loses focus
            self?.stopAllMicrophoneUse()
        }
        
        // Add additional notification for when microphone permissions change
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.deviceWasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // When a microphone is connected/disconnected, stop any active audio
            self?.stopAllMicrophoneUse()
        }
    }
    
    // Function to explicitly request system microphone permission once at startup
    private func requestSystemMicrophonePermission() {
        let audioSession = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if audioSession == .notDetermined {
            print("Requesting system microphone permission")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("System microphone permission granted")
                    // After system permission is granted, update any existing WebViews
                    DispatchQueue.main.async {
                        for webView in self.webViews.values {
                            self.injectPermissionFixer(webView)
                        }
                    }
                } else {
                    print("System microphone permission denied")
                }
            }
        } else if audioSession == .authorized {
            print("System microphone permission already granted")
        }
    }
    
    // Helper method to inject permission fixer scripts with a stronger version for ChatGPT
    private func injectPermissionFixer(_ webView: WKWebView) {
        // Check if this is a ChatGPT webview
        let isChatGPT = webView.url?.host?.contains("chat.openai.com") ?? false
        
        // Use a more aggressive script for ChatGPT
        let script = isChatGPT ? chatGPTPermissionFixerScript() : standardPermissionFixerScript()
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error injecting permission fixer: \(error)")
            } else {
                print("Successfully injected permission fixer")
                
                // For ChatGPT, add an extra script to bypass keychain authentication prompts
                if isChatGPT {
                    self.injectChatGPTKeychainBlocker(webView)
                }
            }
        }
    }
    
    // Standard permission fixer for most services
    private func standardPermissionFixerScript() -> String {
        return """
        (function() {
            // Store active audio streams to stop them later
            if (!window.activeAudioStreams) {
                window.activeAudioStreams = [];
            }
            
            // Force WebView to use already granted permissions without keychain prompts
            if (typeof navigator.mediaDevices !== 'undefined') {
                navigator._getUserMedia = navigator.mediaDevices.getUserMedia;
                navigator.mediaDevices.getUserMedia = async function(constraints) {
                    console.log('Modified getUserMedia called with:', constraints);
                    try {
                        // Force audio to true without prompting
                        if (constraints && constraints.audio) {
                            console.log('Using pre-granted audio permission');
                        }
                        const stream = await navigator._getUserMedia.call(this, constraints);
                        
                        // Store the stream for later cleanup
                        if (stream && constraints.audio) {
                            window.activeAudioStreams.push(stream);
                        }
                        
                        return stream;
                    } catch (err) {
                        console.error('Error in modified getUserMedia:', err);
                        throw err;
                    }
                };
                
                // Also modify legacy getUserMedia if it exists
                if (navigator.getUserMedia) {
                    navigator._legacyGetUserMedia = navigator.getUserMedia;
                    navigator.getUserMedia = function(constraints, success, error) {
                        console.log('Legacy getUserMedia called');
                        return navigator._legacyGetUserMedia.call(this, constraints, function(stream) {
                            // Store the stream for later cleanup
                            if (stream && constraints.audio) {
                                window.activeAudioStreams.push(stream);
                            }
                            success(stream);
                        }, error);
                    };
                }
            }
            
            console.log('WebView permissions fixed to avoid keychain prompts');
        })();
        """
    }
    
    // Enhanced permission fixer specifically for ChatGPT
    private func chatGPTPermissionFixerScript() -> String {
        return """
        (function() {
            console.log('Installing ChatGPT-specific permission handler');
            
            // Store active audio streams and contexts to stop them later
            if (!window.activeAudioStreams) {
                window.activeAudioStreams = [];
            }
            
            // Block any credential storage
            if (window.PasswordCredential) {
                window.PasswordCredential = function() { 
                    console.log('Blocked PasswordCredential creation');
                    return {}; 
                };
            }
            
            // Override the Credential Management API if it exists
            if (navigator.credentials) {
                const originalStore = navigator.credentials.store;
                navigator.credentials.store = function(credential) {
                    console.log('Blocked credential storage attempt');
                    return Promise.resolve(null);
                };
                
                const originalGet = navigator.credentials.get;
                navigator.credentials.get = function(options) {
                    console.log('Blocked credential retrieval attempt');
                    return Promise.resolve(null);
                };
            }
            
            // Override getUserMedia with a version that doesn't trigger keychain
            if (navigator.mediaDevices) {
                const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                navigator.mediaDevices.getUserMedia = async function(constraints) {
                    console.log('ChatGPT: Intercepted getUserMedia call with:', constraints);
                    
                    // If requesting audio only - create a dummy track to avoid permission prompts
                    if (constraints && constraints.audio && !constraints.video) {
                        try {
                            // Try the normal way first
                            const stream = await originalGetUserMedia.call(this, constraints);
                            // Store the stream for later cleanup
                            window.activeAudioStreams.push(stream);
                            return stream;
                        } catch (err) {
                            console.log('ChatGPT: Creating dummy audio track to bypass permission issues');
                            try {
                                // Create a dummy audio track that doesn't require keychain
                                const ctx = new AudioContext();
                                window.activeAudioContext = ctx; // Store for later cleanup
                                
                                const oscillator = ctx.createOscillator();
                                window.activeOscillator = oscillator; // Store for later cleanup
                                
                                const dst = ctx.createMediaStreamDestination();
                                oscillator.connect(dst);
                                oscillator.start();
                                const dummyTrack = dst.stream.getAudioTracks()[0];
                                dummyTrack.enabled = false; // Mute it
                                
                                // Create a MediaStream with our dummy track
                                const stream = new MediaStream([dummyTrack]);
                                window.dummyAudioStream = stream; // Store for later cleanup
                                window.activeAudioStreams.push(stream);
                                return stream;
                            } catch (fallbackError) {
                                console.error('Failed to create dummy audio track:', fallbackError);
                                throw err; // Throw the original error
                            }
                        }
                    }
                    
                    // For other requests, use the original implementation
                    const stream = await originalGetUserMedia.call(this, constraints);
                    // Store the stream if it has audio
                    if (constraints && constraints.audio) {
                        window.activeAudioStreams.push(stream);
                    }
                    return stream;
                };
            }
            
            // Also patch enumerateDevices to always return a microphone
            if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
                const originalEnumerate = navigator.mediaDevices.enumerateDevices;
                navigator.mediaDevices.enumerateDevices = async function() {
                    try {
                        const devices = await originalEnumerate.apply(this, arguments);
                        
                        // Check if we already have audio input devices
                        const hasAudioInput = devices.some(device => device.kind === 'audioinput');
                        
                        // If no audio input is found, add a virtual one
                        if (!hasAudioInput) {
                            console.log('ChatGPT: Adding virtual microphone to devices list');
                            devices.push({
                                deviceId: 'virtual-microphone',
                                kind: 'audioinput',
                                label: 'System Microphone',
                                groupId: 'virtual-devices'
                            });
                        }
                        
                        return devices;
                    } catch (error) {
                        console.error('Error in enumerateDevices:', error);
                        // Return a minimal device list with our virtual microphone
                        return [{
                            deviceId: 'virtual-microphone',
                            kind: 'audioinput',
                            label: 'System Microphone',
                            groupId: 'virtual-devices'
                        }];
                    }
                };
            }
            
            console.log('ChatGPT microphone permissions handler installed');
        })();
        """
    }
    
    // Add a special keychain blocker for ChatGPT
    private func injectChatGPTKeychainBlocker(_ webView: WKWebView) {
        let script = """
        (function() {
            // Block keychain popups by overriding methods that trigger them
            
            // Block any password-related form submissions
            document.addEventListener('submit', function(e) {
                const form = e.target;
                
                // Check if this looks like a keychain or credential form
                if (form.querySelector('input[type="password"]')) {
                    console.log('Blocking potential keychain form submission');
                    e.preventDefault();
                    e.stopPropagation();
                    return false;
                }
            }, true);
            
            // Observe for keychain prompts and dismiss them
            const observer = new MutationObserver(function(mutations) {
                // Look for dialogs, popovers, or alerts that might be keychain prompts
                const possiblePrompts = document.querySelectorAll('dialog, [role="dialog"], [aria-modal="true"]');
                
                possiblePrompts.forEach(dialog => {
                    if (dialog.textContent.includes('keychain') || 
                        dialog.textContent.includes('password') ||
                        dialog.textContent.includes('credential')) {
                        
                        console.log('Attempting to dismiss keychain prompt');
                        
                        // Try to find and click cancel/close buttons
                        const closeButtons = dialog.querySelectorAll('button');
                        for (const button of closeButtons) {
                            if (button.textContent.includes('Cancel') || 
                                button.textContent.includes('Close') ||
                                button.textContent.includes('No')) {
                                    
                                console.log('Clicking cancel button');
                                button.click();
                                break;
                            }
                        }
                        
                        // If no button found, try to hide the dialog directly
                        dialog.style.display = 'none';
                        dialog.remove();
                    }
                });
            });
            
            // Start observing for keychain dialogs
            observer.observe(document.body, { 
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['style', 'class']
            });
            
            console.log('ChatGPT keychain blocker installed');
        })();
        """
        
        webView.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("Error injecting ChatGPT keychain blocker: \(error)")
            } else {
                print("Successfully injected ChatGPT keychain blocker")
            }
        }
    }
    
    private func preloadWebViews() {
        for service in aiServices {
            createWebView(for: service)
        }
    }
    
    func webView(for service: AIService) -> WKWebView {
        // In demo mode, always return a new demo web view
        return createWebView(for: service)
    }
    
    func createWebView(for service: AIService) -> WKWebView {
        // In demo mode, create a very basic web view with limited capabilities
        let configuration = WKWebViewConfiguration()
        
        // Disable all storage and caching
        configuration.websiteDataStore = .nonPersistent()
        
        // Disable JavaScript and plugins
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = false
        preferences.javaEnabled = false
        preferences.plugInsEnabled = false
        configuration.preferences = preferences
        
        // Create a basic web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "DemoMode/1.0"
        
        // Load a demo message instead of the actual service URL
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: #f5f5f7;
                    color: #333;
        // Use immediate injection for ChatGPT and Copilot, delayed for others
        if isChatGPT || isCopilot {
            // For ChatGPT/Copilot, inject multiple times with different delays to ensure it works
            let delays = [0.5, 1.0, 2.0, 5.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.injectPermissionFixer(webView)
                    
                    // For Copilot, also inject the special audio monitor
                    if isCopilot {
                        self.injectCopilotAudioCleanupScript(webView)
                    }
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.injectPermissionFixer(webView)
            }
        }
        
        // Track last usage time
        UserDefaults.standard.set(Date(), forKey: "lastUsed_\(service.name)")
        
        return webView
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "mediaPermission" || message.name == "chatGPTHandler" {
            print("Received message from web view: \(message.body)")
            
            // Check if this is reporting voice chat state change
            if let messageDict = message.body as? [String: Any], 
               let type = messageDict["type"] as? String {
                
                // Extract service info if available
                let service = messageDict["service"] as? String
                
                // Check if this is from Copilot and record it
                let isCopilot = service == "copilot" || (message.webView?.url?.host?.contains("copilot.microsoft.com") ?? false)
                
                switch type {
                case "voiceChatStopped", "streamEnded", "recordingStopped", "audioStopped", "forcedAudioStop", "uiClosed":
                    print("Voice chat stopped: \(type)")
                    
                    // Get the reason if available
                    let reason = messageDict["reason"] as? String ?? "unknown"
                    print("Voice chat stopped reason: \(reason)")
                    
                    // If this is from Copilot, remove it from active services
                    if isCopilot {
                        activeVoiceChatServices.remove("copilot")
                        
                        // For Copilot, forcefully stop the microphone to ensure it's fully released
                        if let webView = message.webView {
                            injectCopilotForceStopScript(webView)
                        }
                    }
                    
                    // Set voice chat as inactive, which will trigger cleanup
                    setVoiceChatActive(false)
                    
                    // For explicit user actions, stop microphone immediately
                    if reason == "userClosed" || reason == "escKey" || reason == "uiClosed" || 
                       reason == "hiddenAudioDetected" || reason == "intervalCheck" {
                        // Stop microphone immediately for explicit user actions
                        stopAllMicrophoneUse()
                    }
                    
                case "voiceChatStarted", "voiceButtonClicked", "streamCreated", "recordingStarted":
                    print("Voice chat started: \(type)")
                    
                    // If this is from Copilot, add it to active services
                    if isCopilot {
                        activeVoiceChatServices.insert("copilot")
                    }
                    
                    setVoiceChatActive(true)
                    
                case "permissionDenied", "streamError", "permissionError":
                    // Log the error but don't show a system dialog that might trigger keychain
                    print("Microphone permission issue in webview: \(type)")
                    
                    // Also set voice chat as inactive since there was an error
                    setVoiceChatActive(false)
                    
                case "credentialPrompt":
                    print("Credential prompt detected - fixing")
                    
                    // Re-inject our permission fixer and blocker
                    if let webView = message.webView {
                        injectPermissionFixer(webView)
                        if webView.url?.host?.contains("chat.openai.com") ?? false {
                            injectChatGPTKeychainBlocker(webView)
                        }
                    }
                    
                case "voiceActivityDetected":
                    // Just update the timestamp for voice activity
                    lastVoiceChatActivityTime = Date()
                    
                    // If this is from Copilot, record it
                    if isCopilot {
                        activeVoiceChatServices.insert("copilot")
                    }
                    
                default:
                    print("Unknown message type: \(type)")
                }
            }
        }
    }
    
    func isLoading(for service: AIService) -> Bool {
        return loadingStates[service.id.uuidString] ?? false
    }
    
    func setLoading(_ isLoading: Bool, for service: AIService) {
        loadingStates[service.id.uuidString] = isLoading
    }
    
    func refreshWebView(for service: AIService) {
        guard let webView = webViews[service.id.uuidString] else { return }
        
        // For ChatGPT, perform a special refresh that clears everything first
        if service.name == "ChatGPT" {
            let script = """
            // Clear any stored credentials
            if (navigator.credentials && navigator.credentials.preventSilentAccess) {
                navigator.credentials.preventSilentAccess();
            }
            localStorage.clear();
            sessionStorage.clear();
            """
            
            webView.evaluateJavaScript(script) { (_, _) in
                // After clearing, reload with cache-busting headers
                var request = URLRequest(url: service.url)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                request.setValue("no-store", forHTTPHeaderField: "Pragma")
                webView.load(request)
            }
        } else {
            // Normal reload for other services
            webView.reload()
        }
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
    
    func requestMicrophonePermission() {
        // Check and request system permission first
        requestSystemMicrophonePermission()
        
        // Then try to trigger permission in each webview
        for (serviceID, webView) in webViews {
            // Check if this is ChatGPT
            let isChatGPT = aiServices.first(where: { $0.id.uuidString == serviceID })?.name == "ChatGPT"
            
            let script = isChatGPT ? 
                // Use specialized script for ChatGPT
                """
                // Tell ChatGPT we already have microphone access
                navigator.mediaDevices.enumerateDevices()
                    .then(devices => {
                        // Fake having a microphone already
                        console.log('Faking microphone presence for ChatGPT');
                        
                        // Create a dummy audio context if needed
                        const ctx = new AudioContext();
                        window.activeAudioContext = ctx; // Store for later cleanup
                        
                        const oscillator = ctx.createOscillator();
                        window.activeOscillator = oscillator; // Store for later cleanup
                        
                        const dst = ctx.createMediaStreamDestination();
                        oscillator.connect(dst);
                        oscillator.start();
                        const dummyTrack = dst.stream.getAudioTracks()[0];
                        dummyTrack.enabled = false;
                        
                        // Create a dummy stream
                        const stream = new MediaStream([dummyTrack]);
                        window.dummyAudioStream = stream; // Store for later cleanup
                        
                        // Store the stream in our active streams array
                        if (!window.activeAudioStreams) {
                            window.activeAudioStreams = [];
                        }
                        window.activeAudioStreams.push(stream);
                        
                        // Clean up after short delay (just used for permission check)
                        setTimeout(() => {
                            stream.getTracks().forEach(track => track.stop());
                            oscillator.stop();
                            try { ctx.close(); } catch(e) {}
                            console.log('Cleaned up dummy audio resources after permission check');
                        }, 1000);
                        
                        return stream;
                    })
                    .catch(err => {
                        console.error('ChatGPT microphone setup error:', err);
                    });
                """ :
                // Regular script for other services
                """
                navigator.mediaDevices.getUserMedia({ audio: true })
                    .then(stream => {
                        console.log('Microphone permission granted');
                        
                        // Store the stream in our active streams array for tracking
                        if (!window.activeAudioStreams) {
                            window.activeAudioStreams = [];
                        }
                        window.activeAudioStreams.push(stream);
                        
                        // Immediately stop tracks after permission is granted
                        stream.getTracks().forEach(track => track.stop());
                        console.log('Immediately stopped microphone tracks after permission check');
                    })
                    .catch(err => {
                        console.error('Error getting microphone permission:', err);
                    });
                """
            
            webView.evaluateJavaScript(script) { (_, error) in
                if let error = error {
                    print("Error requesting microphone permission: \(error)")
                } else {
                    // After permission check, ensure we stop microphone
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.injectAudioStopScript(webView)
                    }
                }
            }
        }
    }
} 