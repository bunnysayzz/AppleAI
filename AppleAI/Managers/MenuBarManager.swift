import AppKit
import SwiftUI
// Import WebKit with preconcurrency attribute
@preconcurrency import WebKit

// Import ServiceManagement for login item management
@_exported import ServiceManagement

class MenuBarManager: NSObject, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popupWindow: NSWindow?
    private var shortcutManager: KeyboardShortcutManager!
    private var eventMonitor: Any?
    private var statusMenu: NSMenu!
    private var preferencesWindow: NSWindow?
    private var localEventMonitor: Any?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let iconImage = NSImage(named: "MenuBarIcon") {
                button.image = iconImage
                button.image?.size = NSSize(width: 18, height: 18) // Adjust size to match menu bar
            }
            button.imagePosition = .imageLeft
            
            // Set up the action to handle clicks
            button.target = self
            button.action = #selector(handleStatusItemClick)
            
            // Set up to detect right-clicks
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the menu but don't assign it to the status item yet
        statusMenu = createMenu()
        statusMenu.delegate = self
        
        // Setup keyboard shortcut manager
        shortcutManager = KeyboardShortcutManager(menuBarManager: self)
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenServiceNotification(_:)),
            name: NSNotification.Name("OpenAIService"),
            object: nil
        )
        
        // Setup event monitor to detect clicks outside the window
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.popupWindow else { return }
            
            // Check if the click is outside the window
            if window.isVisible {
                // Don't hide the window if a file picker is active
                if WebViewCache.shared.isFilePickerActive {
                    return
                }
                
                // Don't hide the window if "Always on top" is enabled
                if PreferencesManager.shared.alwaysOnTop {
                    return
                }
                
                let mouseLocation = NSEvent.mouseLocation
                let windowFrame = window.frame
                
                if !NSPointInRect(mouseLocation, windowFrame) {
                    self.closePopupWindow()
                }
            }
        }
    }
    
    deinit {
        // Clean up event monitor
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Remove any observers
        NotificationCenter.default.removeObserver(self)
        
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
    
    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        // Check if it's a right-click
        if event?.type == .rightMouseUp {
            // Show the menu on right-click
            statusItem.menu = statusMenu
            sender.performClick(nil)
            statusItem.menu = nil // Remove the menu after click
        } else {
            // Left-click behavior: toggle the popup window
            if let window = popupWindow, window.isVisible {
                closePopupWindow()
            } else {
                openPopupWindow()
            }
        }
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Open main window - adding Command+E keyboard shortcut
        let openItem = NSMenuItem(
            title: "Open AppleAi Pro",
            action: #selector(togglePopupWindow),
            keyEquivalent: "e"  // "e" for Command+E
        )
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick access to specific AI models
        // Removing the "Quick Access" label as requested
        // menu.addItem(NSMenuItem(title: "Quick Access", action: nil, keyEquivalent: ""))
        
        for (index, service) in aiServices.enumerated() {
            // For Grok, use index 6 if we've added 6 services
            let keyEquivalent = index < 9 ? "\(index + 1)" : "0"
            
            let item = NSMenuItem(
                title: service.name,
                action: #selector(openSpecificService(_:)),
                keyEquivalent: keyEquivalent
            )
            item.target = self
            item.keyEquivalentModifierMask = [.option, .command]
            
            // Create a custom view for the menu item with an icon
            let customView = NSHostingView(rootView: 
                HStack {
                    Image(service.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(service.color)
                    Text(service.name)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘⌥\(keyEquivalent)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, height: 20)
                .padding(.horizontal, 8)
            )
            
            item.view = customView
            item.representedObject = service
            menu.addItem(item)
        }
        
        // Add preferences and quit
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(
            title: "Preferences",
            action: #selector(showPreferences),
            keyEquivalent: ""  // Removed "," keyboard shortcut
        )
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        // Replace "About" with "Azhar" menu item that directly opens GitHub
        let azharItem = NSMenuItem(
            title: "Azhar",
            action: #selector(openGitHub),
            keyEquivalent: ""
        )
        azharItem.target = self
        menu.addItem(azharItem)
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc func togglePopupWindow() {
        if let window = popupWindow, window.isVisible {
            closePopupWindow()
        } else {
            openPopupWindow()
        }
    }
    
    private func closePopupWindow() {
        // Just hide the window rather than closing it
        popupWindow?.orderOut(nil)
    }
    
    @objc func handleOpenServiceNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let service = userInfo["service"] as? AIService {
            openPopupWindowWithService(service)
        }
    }
    
    @objc func openSpecificService(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? AIService else { return }
        openPopupWindowWithService(service)
    }
    
    @objc internal func windowDidBecomeKey(_ notification: Notification) {
        // Ensure the web view becomes first responder when the window becomes key
        if let window = notification.object as? NSWindow {
            // Recursively search for WKWebView and make it first responder
            // Use a sequence of timed attempts to ensure views are ready
            makeWebViewFirstResponderWithRetry(window: window)
        }
    }
    
    private func makeWebViewFirstResponderWithRetry(window: NSWindow) {
        // Multiple attempts at different times to handle race conditions
        let delays: [TimeInterval] = [0.1, 0.3, 0.5, 0.8]
        
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.findAndFocusWebView(in: window.contentView)
            }
        }
    }
    
    private func findAndFocusWebView(in view: NSView?) {
        guard let view = view else { return }
        
        // Try to find KeyboardResponderView first (best option)
        if NSStringFromClass(type(of: view)).contains("KeyboardResponderView") {
            DispatchQueue.main.async {
                if let window = view.window {
                    window.makeFirstResponder(view)
                }
            }
            return
        }
        
        // Then try to find WKWebView
        if NSStringFromClass(type(of: view)).contains("WKWebView") {
            DispatchQueue.main.async {
                if let window = view.window {
                    window.makeFirstResponder(view)
                }
            }
            return
        }
        
        // Recursively check subviews
        for subview in view.subviews {
            findAndFocusWebView(in: subview)
        }
    }
    
    private func openPopupWindow() {
        // If window already exists, just show it
        if let window = popupWindow {
            positionAndShowPopupWindow(window)
            return
        }
        
        // Create a new popup window with only titlebar and close button
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        window.title = "AppleAi Pro"
        window.isReleasedWhenClosed = false // Important: Don't release window when closed
        
        // Set initial window level based on preference
        window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
        
        // Set collection behavior to ensure it appears on current space
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        
        // Enable keyboard event handling
        window.acceptsMouseMovedEvents = true
        window.isMovable = true
        
        // Critical for keyboard input
        window.initialFirstResponder = nil // Let SwiftUI handle first responder
        window.allowsToolTipsWhenApplicationIsInactive = true
        window.hidesOnDeactivate = false
        
        // Set up keyboard event monitoring for this window to intercept problematic keys
        setupWindowKeyEventMonitoring(window)
        
        // Set the window delegate to handle close button
        window.delegate = self
        
        // Add pin button to title bar
        addPinButtonToTitleBar(window)
        
        // Set the content view to our CompactChatView
        let contentView = CompactChatView(closeAction: { [weak self] in
            self?.closePopupWindow()
        })
        window.contentView = NSHostingView(rootView: contentView)
        
        // Store the window
        popupWindow = window
        
        // Position and show the window
        positionAndShowPopupWindow(window)
        
        // Register for window focus notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }
    
    // Add a key event monitor to prevent problematic keys from causing the app to quit
    private func setupWindowKeyEventMonitoring(_ window: NSWindow) {
        // Add a local monitor for key events to prevent app quitting
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let window = self.popupWindow, event.window == window else {
                return event
            }
            
            // Check for Copilot voice chat activity
            if self.isInCopilotVoiceChat(window) {
                // When in Copilot voice chat, let all keypresses through to the window
                return event
            }
            
            // Check if we have a first responder
            guard let firstResponder = window.firstResponder else {
                // If no first responder, toggle the window off instead of letting the event propagate
                self.closePopupWindow()
                return nil // Consume the event
            }
            
            // Check if the first responder is a text field, KeyboardResponderView, or a WKWebView
            let firstResponderClass = NSStringFromClass(type(of: firstResponder))
            let isInput = firstResponderClass.contains("WKWebView") ||
                          firstResponderClass.contains("KeyboardResponderView") ||
                          firstResponderClass.contains("NSTextField") ||
                          firstResponderClass.contains("NSTextView")
            
            if isInput {
                // Let the input handle all keystrokes
                return event
            } else {
                // For non-input first responders, toggle the window off instead of letting the event propagate
                // This prevents any key from quitting the app
                self.closePopupWindow()
                return nil // Consume the event
            }
        }
    }
    
    // Helper method to check if Copilot voice chat is active
    private func isInCopilotVoiceChat(_ window: NSWindow) -> Bool {
        // Find Copilot webView in the window
        var foundWebView: WKWebView? = nil
        
        // Function to recursively search for WKWebView
        func findWKWebView(in view: NSView) -> WKWebView? {
            // Check if this view is a WKWebView
            if let webView = view as? WKWebView {
                return webView
            }
            
            // Search in subviews
            for subview in view.subviews {
                if let webView = findWKWebView(in: subview) {
                    return webView
                }
            }
            
            return nil
        }
        
        // Find WKWebView in the window's content view
        if let contentView = window.contentView {
            foundWebView = findWKWebView(in: contentView)
        }
        
        // Check if it's a Copilot webview and if voice chat is active
        if let webView = foundWebView,
           let url = webView.url,
           url.host?.contains("copilot.microsoft.com") == true {
            // Check for voice chat UI elements
            let voiceChatScript = """
            (function() {
                return document.querySelectorAll(
                    '[aria-label="Stop voice input"], ' +
                    '.voice-input-container:not(.hidden), ' +
                    '[data-testid="voice-input-button"].active, ' +
                    '.voice-input-active, ' +
                    '.sydney-voice-input'
                ).length > 0;
            })();
            """
            
            var isVoiceChat = false
            let semaphore = DispatchSemaphore(value: 0)
            
            webView.evaluateJavaScript(voiceChatScript) { (result, error) in
                if let isActive = result as? Bool {
                    isVoiceChat = isActive
                }
                semaphore.signal()
            }
            
            // Wait with a short timeout
            _ = semaphore.wait(timeout: .now() + 0.05)
            
            return isVoiceChat
        }
        
        return false
    }
    
    private func openPopupWindowWithService(_ service: AIService) {
        // If window doesn't exist, create it with the specific service
        if popupWindow == nil {
            // Create a new popup window with only titlebar and close button
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            // Configure the window
            window.title = "AppleAi Pro"
            window.isReleasedWhenClosed = false // Important: Don't release window when closed
            
            // Set initial window level based on preference
            window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
            
            // Set collection behavior to ensure it appears on current space
            window.collectionBehavior = [.moveToActiveSpace, .transient]
            
            // Enable keyboard event handling
            window.acceptsMouseMovedEvents = true
            window.isMovable = true
            
            // Critical for keyboard input
            window.initialFirstResponder = nil // Let SwiftUI handle first responder
            window.allowsToolTipsWhenApplicationIsInactive = true
            window.hidesOnDeactivate = false
            
            // Set up keyboard event monitoring
            setupWindowKeyEventMonitoring(window)
            
            // Set the window delegate to handle close button
            window.delegate = self
            
            // Add pin button to title bar
            addPinButtonToTitleBar(window)
            
            // Set the content view to our CompactChatView with the specific service
            let contentView = CompactChatView(
                initialService: service,
                closeAction: { [weak self] in
                    self?.closePopupWindow()
                }
            )
            window.contentView = NSHostingView(rootView: contentView)
            
            // Store the window
            popupWindow = window
            
            // Position and show the window
            positionAndShowPopupWindow(window)
            
            // Register for window focus notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            return
        }
        
        // If window exists, update the selected service
        if let window = popupWindow {
            // Create a new CompactChatView with the selected service
            let contentView = CompactChatView(
                initialService: service,
                closeAction: { [weak self] in
                    self?.closePopupWindow()
                }
            )
            window.contentView = NSHostingView(rootView: contentView)
            
            // Position and show the window
            positionAndShowPopupWindow(window)
        }
    }
    
    private func positionAndShowPopupWindow(_ window: NSWindow) {
        // Ensure the window appears on the active space
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        
        // Set window level based on alwaysOnTop preference
        window.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
        
        // Position the window below the status item
        if let button = statusItem.button {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = button.window?.convertToScreen(buttonRect)
            
            if let screenRect = screenRect {
                let windowSize = window.frame.size
                let x = screenRect.midX - windowSize.width / 2
                let y = screenRect.minY - windowSize.height
                
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        // Ensure window is properly configured for keyboard input
        window.makeKeyAndOrderFront(nil)
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        
        // Make the window active and bring app to foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Attempt to set focus to the webview with multiple timed attempts
        makeWebViewFirstResponderWithRetry(window: window)
        
        // Setup window level observer to update when alwaysOnTop changes
        setupWindowLevelObserver(for: window)
    }
    
    // Add observer to update window level when alwaysOnTop preference changes
    private func setupWindowLevelObserver(for window: NSWindow) {
        // Remove existing observer if any
        NotificationCenter.default.removeObserver(self, name: Notification.Name("AlwaysOnTopChanged"), object: nil)
        
        // Add observer for AlwaysOnTopChanged notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindowLevel),
            name: Notification.Name("AlwaysOnTopChanged"),
            object: nil
        )
    }
    
    @objc private func updateWindowLevel() {
        guard let window = popupWindow else { return }
        
        // Update window level based on preference with animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal
        })
    }
    
    @objc func showPreferences() {
        // If window already exists, just show it
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new window with non-standard close behavior
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // Important: Set this to false to prevent the window from being deallocated when closed
        window.isReleasedWhenClosed = false
        
        window.title = "Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set the delegate to self to track window close
        window.delegate = self
        
        // Store the window
        preferencesWindow = window
    }
    
    @objc func openGitHub() {
        // Open GitHub URL when "Azhar" is clicked
        if let url = URL(string: "https://github.com/bunnysayzz") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuDidClose(_ menu: NSMenu) {
        // Ensure the menu is removed after it's closed
        statusItem.menu = nil
    }
    
    // Add a new method to add the pin button to the title bar
    private func addPinButtonToTitleBar(_ window: NSWindow) {
        // Create a SwiftUI hosting controller for the enhanced pin button
        let hostingController = NSHostingController(rootView: 
            EnhancedPinButton(
                isPinned: Binding<Bool>(
                    get: { PreferencesManager.shared.alwaysOnTop },
                    set: { PreferencesManager.shared.setAlwaysOnTop($0) }
                )
            )
        )
        
        // Size the view appropriately - make it a bit larger for better visibility
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 36, height: 30)
        
        // Create a title bar accessory view controller with more breathing room
        let accessoryViewController = NSTitlebarAccessoryViewController()
        accessoryViewController.view = hostingController.view
        accessoryViewController.layoutAttribute = .trailing
        
        // Add the accessory view controller to the window
        window.addTitlebarAccessoryViewController(accessoryViewController)
    }
    
    // MARK: - NSWindowDelegate
    
    @objc func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Check if this is the preferences window
        if window == preferencesWindow {
            // Don't set to nil, just hide the window
            window.orderOut(nil)
            print("Preferences window hidden but retained")
            
            // Instead of allowing the normal close behavior, we'll prevent it
            DispatchQueue.main.async {
                // This is important: we're not allowing the window to close normally
                // It will just be hidden, not released or deallocated
                window.orderOut(nil) // Hide the window instead of trying to set isVisible
            }
        }
    }
    
    // Return false to prevent normal window closing behavior for preferences
    @objc func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Handle each window type differently
        if sender == popupWindow {
            // For the main popup window, just hide it
            closePopupWindow()
            return false // Prevent standard close behavior
        } else if sender == preferencesWindow {
            // For the preferences window, hide it but allow the close action
            preferencesWindow?.orderOut(nil)
            return false // Prevent standard close behavior but still hide
        }
        
        // Allow normal closing for any other windows
        return true
    }
    
    // Prevent window minimization
    func windowShouldMiniaturize(_ sender: NSWindow) -> Bool {
        // Always prevent minimization of our popup window
        if sender == popupWindow {
            return false
        }
        return true // Allow minimization for other windows
    }
    
    // Prevent window zoom (maximize)
    @objc func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        // Always prevent zoom for our popup window
        if window == popupWindow {
            return false
        }
        return true // Allow zoom for other windows
    }
}

// Add the enhanced pin button view
struct EnhancedPinButton: View {
    @Binding var isPinned: Bool
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var animatePin = false
    @State private var pulsate = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPinned.toggle()
                isPressed = true
                
                // Trigger pin animation
                animatePin = true
                
                // Reset press state after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPressed = false
                }
                
                // Reset animation trigger after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    animatePin = false
                }
                
                // Start pulsating if pinned
                if isPinned {
                    startPulseAnimation()
                }
            }
        }) {
            ZStack {
                // Animated glow effect for pinned state
                if isPinned {
                    Circle()
                        .fill(Color.accentColor)
                        .opacity(pulsate ? 0.2 : 0.0)
                        .scaleEffect(pulsate ? 1.3 : 0.8)
                        .frame(width: 30, height: 30)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsate)
                }
                
                // Background shape
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isPinned 
                        ? Color.accentColor.opacity(isHovered ? 0.7 : 0.5) 
                        : (isHovered ? Color.secondary.opacity(0.3) : Color.clear)
                    )
                    .frame(width: 28, height: 28)
                    .scaleEffect(isPressed ? 0.85 : 1.0)
                    .shadow(color: isPinned ? Color.accentColor.opacity(0.5) : Color.clear, 
                           radius: isPinned ? 3 : 0, 
                           x: 0, y: isPinned ? 1 : 0)
                
                // Pin icon with enhanced animations
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isPinned ? Color.white : (isHovered ? Color.primary : Color.secondary))
                    .rotationEffect(Angle(degrees: isPinned ? 0 : 45))
                    .scaleEffect(animatePin ? 1.4 : 1.0)
                    .shadow(color: isPinned ? Color.accentColor.opacity(0.7) : Color.clear, radius: animatePin ? 4 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animatePin)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isPinned)
                    .blur(radius: animatePin && isPinned ? 0.5 : 0)
            }
            .overlay(
                // Add a subtle border that glows when pinned
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isPinned ? Color.accentColor : Color.clear,
                        lineWidth: isPinned ? 1.5 : 0
                    )
                    .opacity(isHovered && !isPinned ? 0.7 : 1.0)
            )
            // Add a slight 3D effect with offset
            .offset(y: isPressed ? 1 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            
            // Give subtle feedback on hover with haptic-like animation
            if hovering && !isPressed {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                    }
                }
            }
        }
        .help(isPinned ? "Unpin window (Currently stays on top)" : "Pin window to stay on top")
        .onAppear {
            // Start pulsing animation if pinned when view appears
            if isPinned {
                startPulseAnimation()
            }
        }
        .onChange(of: isPinned) { newValue in
            // Start or stop pulsating based on pin state
            if newValue {
                startPulseAnimation()
            } else {
                pulsate = false
            }
        }
    }
    
    // Helper function to start the pulsing animation
    private func startPulseAnimation() {
        pulsate = true
    }
} 