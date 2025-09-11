import SwiftUI
import AppKit
@_exported import WebKit

@main
struct AIToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// App delegate to handle application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager!
    private var microphoneMonitorTimer: Timer?
    private var keyEventMonitor: Any?
    private var flagsEventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (menu bar app)
        NSApp.setActivationPolicy(.accessory)
        
        // Create and setup the menu bar manager
        menuBarManager = MenuBarManager()
        menuBarManager.setup()
        
        // Initialize Pro notification manager
        _ = ProNotificationManager.shared
        
        // Setup application main menu with keyboard shortcut support
        setupMainMenu()
        
        // MAXIMUM PROTECTION: Install truly global keyboard monitors
        setupApplicationWideKeyboardBlocker()
        
        // Also install our regular keyboard handlers for when in text fields
        setupKeyboardEvents()
        
        // Prevent app termination by adding a persistent window
        createPersistentWindow()
        
        // Register for termination notification to manually handle app termination
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        
        // Ensure microphone is stopped at app startup
        stopMicrophoneUsage()
        
        // Start a periodic microphone monitor to prevent the microphone
        // from staying active when it shouldn't be
        startMicrophoneMonitor()
    }
    
    // FORTRESS MODE: This aggressively blocks ALL keyboard events system-wide
    // except for Command+E. Nothing else gets through.
    private func setupApplicationWideKeyboardBlocker() {
        // Remove any existing monitors
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = flagsEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        print("Installing FORTRESS MODE keyboard protection")
        
        // LEVEL 1: Global monitor that catches ALL key events
        keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Global monitor can only observe events, not block them
            // But we'll use it for logging suspicious activity
            if let self = self {
                // Log any key press when we're not expecting it
                print("GLOBAL: Key event detected: \(event.keyCode) [\(event.charactersIgnoringModifiers ?? "")]")
            }
        }
        
        // LEVEL 2: Local monitor that catches ALL key down events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            print("FORTRESS: Intercepted key \(event.keyCode) [\(event.charactersIgnoringModifiers ?? "")]")
            
            // SPECIAL CASE 0: Block ESC key (0x35) in all contexts to prevent quitting
            // Only block Enter key (0x24) when NOT in a text field
            if event.keyCode == 0x35 || (event.keyCode == 0x24 && !self.isInTextInputField(event.window?.firstResponder)) {
                print("FORTRESS: Blocking ESC/Enter key to prevent app quit")
                return nil
            }
            
            // SPECIAL CASE 1: ALWAYS allow Command+E to trigger our toggle
            if event.modifierFlags.contains(.command) && 
               event.keyCode == 0x0E && 
               event.charactersIgnoringModifiers == "e" {
                print("FORTRESS: Allowing Command+E shortcut")
                return event
            }
            
            // SPECIAL CASE 2: Allow Command+Q but ONLY if it comes from the menu
            if event.modifierFlags.contains(.command) && 
               event.keyCode == 0x0C && 
               event.charactersIgnoringModifiers == "q" {
                
                // Only allow if the first responder is actually an NSMenuItem
                if let firstResponder = NSApp.keyWindow?.firstResponder {
                    let responderClass = String(describing: type(of: firstResponder))
                    if responderClass.contains("NSMenu") || responderClass.contains("NSMenuItem") {
                        print("FORTRESS: Allowing Command+Q from menu item")
                        return event
                    }
                }
                
                print("FORTRESS: Blocking Command+Q not from menu")
                return nil
            }
            
            // SPECIAL CASE 3: Allow key events ONLY when we're in a known text input field
            if let window = event.window, window.isKeyWindow,
               let firstResponder = window.firstResponder {
                
                let responderClass = String(describing: type(of: firstResponder))
                
                // Check for our special KeyboardResponderView or its descendants
                let isInKeyboardView = responderClass.contains("KeyboardResponderView") ||
                                      self.isDescendantOfKeyboardResponderView(firstResponder)
                
                // Very strict check for text field context
                let isTextInputField = 
                    (responderClass.contains("NSTextInputContext") || 
                     responderClass.contains("NSTextView") ||
                     responderClass.contains("WKContentView") ||
                     responderClass.contains("TextInputHost") ||
                     responderClass.contains("NSTextField") ||
                     responderClass.contains("UITextView")) || 
                    // Verify we're truly in a web view input context by checking parent chain
                    self.isInsideWebViewEditingContext(firstResponder) ||
                    // Our KeyboardResponderView handles its own input checking
                    isInKeyboardView
                
                if isTextInputField {
                    // Inside text field, allow normal typing
                    if event.modifierFlags.contains(.command) {
                        // But only allow standard editing shortcuts
                        let standardShortcuts: [UInt16] = [
                            UInt16(0x00), // A - Select All
                            UInt16(0x08), // C - Copy
                            UInt16(0x09), // V - Paste
                            UInt16(0x07), // X - Cut
                            UInt16(0x0C), // Z - Undo
                            UInt16(0x0D)  // Y - Redo
                        ]
                        
                        if standardShortcuts.contains(event.keyCode) {
                            print("FORTRESS: Allowing standard editing shortcut in text field")
                            return event
                        } else {
                            print("FORTRESS: Blocking non-standard shortcut in text field: \(event.keyCode)")
                            return nil
                        }
                    } else {
                        // Block ESC key in all contexts, but allow Enter key in text fields for submission
                        if event.keyCode == 0x35 {
                            print("FORTRESS: Blocking ESC key in text field")
                            return nil
                        }
                        
                        // Allow normal typing in verified text fields
                        print("FORTRESS: Allowing normal typing in text field")
                        return event
                    }
                }
            }
            
            // EXTREME FORTRESS: Block absolutely ALL other key events in all contexts
            // This is the ultimate protection against unexpected quits
            print("FORTRESS: Blocking key event \(event.keyCode) completely")
            return nil
        }
        
        // LEVEL 3: Also install protection for flags changed events (modifier keys)
        flagsEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            // Allow all modifier key events as they don't trigger quits directly
            return event
        }
    }
    
    // Helper to check if a responder is or is descended from KeyboardResponderView
    private func isDescendantOfKeyboardResponderView(_ responder: NSResponder) -> Bool {
        let responderClass = String(describing: type(of: responder))
        if responderClass.contains("KeyboardResponderView") {
            return true
        }
        
        // Check up the responder chain
        var current = responder.nextResponder
        var depth = 0
        while current != nil && depth < 5 {
            let currentClass = String(describing: type(of: current!))
            if currentClass.contains("KeyboardResponderView") {
                return true
            }
            current = current!.nextResponder
            depth += 1
        }
        
        return false
    }
    
    // Helper method to deeply verify we're in a true web view editing context
    private func isInsideWebViewEditingContext(_ responder: NSResponder) -> Bool {
        // First check directly
        let responderClass = String(describing: type(of: responder))
        if responderClass.contains("WKContentView") || 
           responderClass.contains("WKWebView") {
            return true
        }
        
        // Recursively check responder chain up to 5 levels deep
        var currentResponder = responder.nextResponder
        var depth = 0
        
        while currentResponder != nil && depth < 5 {
            let currentClass = String(describing: type(of: currentResponder!))
            
            if currentClass.contains("WKContentView") || 
               currentClass.contains("WKWebView") || 
               currentClass.contains("AIWebView") ||
               currentClass.contains("KeyboardResponderView") {
                return true
            }
            
            currentResponder = currentResponder!.nextResponder
            depth += 1
        }
        
        // Not in a web view context
        return false
    }
    
    // Stop any microphone usage to ensure privacy
    private func stopMicrophoneUsage() {
        // Use WebViewCache to stop all audio resources
        let webViewCache = WebViewCache.shared
        DispatchQueue.main.async {
            webViewCache.stopAllMicrophoneUse()
        }
    }
    
    // Start a periodic monitor to check for and stop microphone usage when inactive
    private func startMicrophoneMonitor() {
        // Cancel any existing timer
        microphoneMonitorTimer?.invalidate()
        
        // Create a new timer that checks microphone status every 3 seconds
        microphoneMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAndStopInactiveMicrophone()
        }
    }
    
    // Check if microphone is active but should be inactive, and stop it if needed
    private func checkAndStopInactiveMicrophone() {
        // Access WebViewCache instance
        let webViewCache = WebViewCache.shared
        
        // Instead of accessing private webViews dictionary, use a shared approach
        // to stop all microphone usage first
        webViewCache.stopAllMicrophoneUse()
        
        // Then perform a scheduled check to make sure all audio is actually stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Run JavaScript in the current web view to check status
            if let currentWebView = self.getCurrentActiveWebView() {
                currentWebView.evaluateJavaScript("""
                (function() {
                    // Check if there are any active audio tracks in this page
                    let hasActiveAudio = false;
                    
                    // Check all active audio streams
                    if (window.activeAudioStreams && window.activeAudioStreams.length > 0) {
                        for (const stream of window.activeAudioStreams) {
                            if (stream && typeof stream.getAudioTracks === 'function') {
                                const audioTracks = stream.getAudioTracks();
                                if (audioTracks.some(track => track.readyState === 'live')) {
                                    hasActiveAudio = true;
                                }
                            }
                        }
                    }
                    
                    // If we still have active audio, stop it forcefully
                    if (hasActiveAudio) {
                        // Force stop all audio tracks
                        console.log('Force stopping audio tracks');
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
                            
                            // Clear active streams array
                            window.activeAudioStreams = [];
                        }
                    }
                    
                    return hasActiveAudio;
                })();
                """) { (result, error) in
                    if let error = error {
                        print("Error checking audio status: \(error)")
                    } else if let hasActiveAudio = result as? Bool, hasActiveAudio {
                        print("Detected active audio and stopped it forcefully")
                    }
                }
            }
        }
    }
    
    // Helper to get the current active web view
    private func getCurrentActiveWebView() -> WKWebView? {
        // Find the main window
        guard let mainWindow = NSApp.windows.first(where: { $0.title == "AppleAi Pro" }) else {
            return nil
        }
        
        // Try to find the WKWebView within the window hierarchy
        func findWebView(in view: NSView?) -> WKWebView? {
            guard let view = view else { return nil }
            
            // Check if this view is a WKWebView
            if let webView = view as? WKWebView {
                return webView
            }
            
            // Otherwise, recursively search in subviews
            for subview in view.subviews {
                if let webView = findWebView(in: subview) {
                    return webView
                }
            }
            
            return nil
        }
        
        return findWebView(in: mainWindow.contentView)
    }
    
    // This is critical - it prevents the app from terminating when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Add a hidden persistent window to prevent app termination
    private func createPersistentWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.orderOut(nil)
    }
    
    @objc func appWillTerminate() {
        // Perform cleanup if needed
        print("App is terminating")
        
        // Invalidate the microphone monitor timer
        microphoneMonitorTimer?.invalidate()
        
        // Stop microphone usage when app is terminating
        stopMicrophoneUsage()
    }
    
    // This method is called when the user attempts to quit your app
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Invalidate the microphone monitor timer
        microphoneMonitorTimer?.invalidate()
        
        // Stop microphone usage before terminating
        stopMicrophoneUsage()
        
        // Allow termination
        return .terminateNow
    }
    
    // Handle app entering background
    func applicationDidResignActive(_ notification: Notification) {
        // Stop microphone when app goes into background
        stopMicrophoneUsage()
    }
    
    // Handle when app is hidden
    func applicationWillHide(_ notification: Notification) {
        // Stop microphone when app is hidden
        stopMicrophoneUsage()
    }
    
    private func setupKeyboardEvents() {
        // SUPER-STRICT MODE: Block ALL key events unless explicitly allowed
        // This prevents any key from quitting the app unexpectedly
        
        // First monitor: Aggressively block ALL keyboard events by default
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            print("Key event detected: \(event.keyCode) - \(event.charactersIgnoringModifiers ?? "")")
            
            // 1. ALWAYS allow Command+E toggle shortcut regardless of context
            if event.modifierFlags.contains(.command) && 
               event.keyCode == 0x0E && 
               event.charactersIgnoringModifiers == "e" {
                return event // Always allow Command+E to toggle
            }
            
            // 2. Check if we're in a text field/input context
            if let window = event.window, window.isKeyWindow,
               let firstResponder = window.firstResponder {
                
                let responderClass = NSStringFromClass(type(of: firstResponder))
                
                // Check if we're in a text input field or text editor
                let isTextInputField = responderClass.contains("NSText") || 
                                     responderClass.contains("WKWebView") || 
                                     responderClass.contains("NSTextField") ||
                                     responderClass.contains("KeyboardResponderView") ||
                                     responderClass.contains("NSTextInputContext") ||
                                     responderClass.contains("NSTextView")
                
                // Allow key events in text input fields
                if isTextInputField {
                    // In text field, only allow standard text editing shortcuts and normal typing
                    if event.modifierFlags.contains(.command) {
                        // Allow only specific standard text editing shortcuts
                        let standardShortcuts: [UInt16] = [
                            UInt16(0x00), // A - Select All
                            UInt16(0x08), // C - Copy
                            UInt16(0x09), // V - Paste
                            UInt16(0x07), // X - Cut
                            UInt16(0x0C), // Z - Undo
                            UInt16(0x0D)  // Y - Redo
                        ]
                        
                        if standardShortcuts.contains(event.keyCode) {
                            return event // Allow standard text editing shortcuts
                        }
                        
                        // SUPER-STRICT: Specifically block Command+Q and Command+W
                        if event.keyCode == 0x0C || event.keyCode == 0x0D {
                            print("Blocked Command+Q/W in text field")
                            return nil
                        }
                        
                        // Block all other command shortcuts when in text field
                        print("Blocked command shortcut in text field: \(event.keyCode)")
                        return nil
                    }
                    
                    // Allow regular typing in text fields
                    return event
                }
                
                // For menu items, we allow Command+Q to work properly
                if responderClass.contains("NSMenu") || responderClass.contains("MenuItem") {
                    // Special case: Only allow Command+Q if it's from menu
                    if event.modifierFlags.contains(.command) && 
                       event.keyCode == 0x0C && 
                       event.charactersIgnoringModifiers == "q" {
                        // This is Command+Q from the menu, allow it
                        return event
                    }
                    
                    // Allow other menu interactions
                    return event
                }
                
                // ULTRA-STRICT: Block absolutely ALL other key events when not in a text field
                // This is the key change to prevent random keys from quitting during the focus delay
                print("ULTRA-STRICT: Blocking ALL key event outside text field: \(event.keyCode)")
                return nil
            }
            
            // Block ALL key events by default if we can't determine context
            // This is safer than potentially allowing a quit command
            print("Default blocking unknown context key event: \(event.keyCode)")
            return nil
        }
        
        // Add a second fail-safe monitor to catch any events that might slip through
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Block ESC key (0x35) as a top priority, but only block Enter (0x24) outside text fields
            if event.keyCode == 0x35 || (event.keyCode == 0x24 && !self.isInTextInputField(NSApp.keyWindow?.firstResponder)) {
                print("FAIL-SAFE: Blocked ESC/Enter key")
                return nil
            }
            
            // Last line of defense - specifically block ANY Command+Q/W that gets through
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 0x0C && event.charactersIgnoringModifiers == "q" {
                    // Double-check if this is from menu
                    if let firstResponder = NSApp.keyWindow?.firstResponder,
                       !NSStringFromClass(type(of: firstResponder)).contains("NSMenu") {
                        print("FAIL-SAFE: Blocked Command+Q")
                        return nil
                    }
                }
                
                if event.keyCode == 0x0D && event.charactersIgnoringModifiers == "w" {
                    // Double-check if this is from menu
                    if let firstResponder = NSApp.keyWindow?.firstResponder,
                       !NSStringFromClass(type(of: firstResponder)).contains("NSMenu") {
                        print("FAIL-SAFE: Blocked Command+W")
                        return nil
                    }
                }
            }
            
            // Let other events pass through to the next handler
            return event
        }
        
        // Add a third safety layer that catches ALL key up events to be extra safe
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            // For key up events, use the same strict logic to be consistent
            if let window = event.window, window.isKeyWindow,
               let firstResponder = window.firstResponder {
                
                let responderClass = NSStringFromClass(type(of: firstResponder))
                
                // Only allow key up events in text fields or menu items
                let isAllowedContext = responderClass.contains("NSText") || 
                                    responderClass.contains("WKWebView") || 
                                    responderClass.contains("NSTextField") ||
                                    responderClass.contains("KeyboardResponderView") ||
                                    responderClass.contains("NSMenu") ||
                                    responderClass.contains("MenuItem")
                
                if isAllowedContext {
                    return event
                }
                
                // Block all other key up events
                return nil
            }
            
            // Block by default
            return nil
        }
        
        // Also monitor flag changed events (modifier keys) for consistency
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            // Allow all modifier key changes as they don't typically trigger app quit
            return event
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Application menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "AppleAi Pro", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        
        // Add about item
        let aboutItem = NSMenuItem(title: "About AppleAi Pro", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        aboutItem.target = NSApp
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add preferences item
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(menuBarManager.showPreferences), keyEquivalent: ",")
        prefsItem.target = menuBarManager
        appMenu.addItem(prefsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add quit item
        let quitItem = NSMenuItem(title: "Quit AppleAi Pro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        
        // File menu with Open AI interface command
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        
        // Add open AI interface item with Command+E shortcut - keep this as the only custom shortcut
        let openItem = NSMenuItem(title: "Open AI Interface", action: #selector(menuBarManager.togglePopupWindow), keyEquivalent: "e")
        openItem.target = menuBarManager
        fileMenu.addItem(openItem)
        
        // Add main menu items to the application's main menu
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        
        // Set the app's main menu
        NSApp.mainMenu = mainMenu
    }
    
    deinit {
        // Clean up event monitors
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = flagsEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // Add a helper method to check if we're in a text input field where Enter should work
    private func isInTextInputField(_ responder: NSResponder?) -> Bool {
        guard let responder = responder else { return false }
        
        let responderClass = String(describing: type(of: responder))
        
        // Check if this is a text input context where Enter should be allowed
        let isTextField = responderClass.contains("NSTextInputContext") || 
                         responderClass.contains("NSTextView") ||
                         responderClass.contains("WKContentView") ||
                         responderClass.contains("TextInputHost") ||
                         responderClass.contains("NSTextField") ||
                         responderClass.contains("UITextView") ||
                         responderClass.contains("KeyboardResponderView")
        
        if isTextField {
            return true
        }
        
        // Also check if we're in a web view context
        if isInsideWebViewEditingContext(responder) {
            return true
        }
        
        return false
    }
} 