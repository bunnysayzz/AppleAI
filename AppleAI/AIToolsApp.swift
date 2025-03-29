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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (menu bar app)
        NSApp.setActivationPolicy(.accessory)
        
        // Create and setup the menu bar manager
        menuBarManager = MenuBarManager()
        menuBarManager.setup()
        
        // Setup application main menu with keyboard shortcut support
        setupMainMenu()
        
        // Register for global keyboard shortcut at application level
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
        guard let mainWindow = NSApp.windows.first(where: { $0.title == "Apple AI" }) else {
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
        // Monitor keyboard events for text input fields
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Allow standard keyboard shortcuts (copy, paste, select all) 
            // for text fields in any window
            let standardShortcuts: [UInt16] = [
                UInt16(0x00), // A - Select All
                UInt16(0x08), // C - Copy
                UInt16(0x09), // V - Paste
                UInt16(0x07), // X - Cut
                UInt16(0x0C), // Z - Undo
                UInt16(0x0D)  // Y - Redo
            ]
            
            if event.modifierFlags.contains(.command) && standardShortcuts.contains(event.keyCode) {
                // Make sure we're in a text input before passing these through
                if let window = event.window, 
                   let firstResponder = window.firstResponder {
                    let responderClass = NSStringFromClass(type(of: firstResponder))
                    
                    // Check if the first responder is a text field type or webview
                    if responderClass.contains("NSText") || 
                       responderClass.contains("WKWebView") || 
                       responderClass.contains("KeyboardResponderView") {
                        return event // Pass through to the appropriate responder
                    }
                }
            }
            
            // Return the event unmodified for other cases
            return event
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Application menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "Apple AI", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        
        // Add about item
        let aboutItem = NSMenuItem(title: "About Apple AI", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        aboutItem.target = NSApp
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add preferences item
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(menuBarManager.showPreferences), keyEquivalent: ",")
        prefsItem.target = menuBarManager
        appMenu.addItem(prefsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add quit item
        let quitItem = NSMenuItem(title: "Quit Apple AI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        
        // File menu with Open AI interface command
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        
        // Add open AI interface item with Command+E shortcut
        let openItem = NSMenuItem(title: "Open AI Interface", action: #selector(menuBarManager.togglePopupWindow), keyEquivalent: "e")
        openItem.target = menuBarManager
        fileMenu.addItem(openItem)
        
        // Add main menu items to the application's main menu
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        
        // Set the app's main menu
        NSApp.mainMenu = mainMenu
    }
} 