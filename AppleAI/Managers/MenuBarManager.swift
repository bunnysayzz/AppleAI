import AppKit
import SwiftUI
// Import WebKit with preconcurrency attribute
@preconcurrency import WebKit

// Import ServiceManagement for login item management
@_exported import ServiceManagement

class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popupWindow: NSWindow?
    private var shortcutManager: KeyboardShortcutManager!
    private var eventMonitor: Any?
    private var statusMenu: NSMenu!
    private var preferencesWindow: NSWindow?
    
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
            title: "Open Apple AI",
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
        window.title = "Apple AI"
        window.isReleasedWhenClosed = false // Important: Don't release window when closed
        window.level = .normal
        
        // Set collection behavior to ensure it appears on current space
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        
        // Enable keyboard event handling
        window.acceptsMouseMovedEvents = true
        window.isMovable = true
        
        // Critical for keyboard input
        window.initialFirstResponder = nil // Let SwiftUI handle first responder
        window.allowsToolTipsWhenApplicationIsInactive = true
        window.hidesOnDeactivate = false
        
        // Set the window delegate to handle close button
        window.delegate = self
        
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
    
    @objc internal func windowDidBecomeKey(_ notification: Notification) {
        // Ensure the web view becomes first responder when the window becomes key
        if let window = notification.object as? NSWindow {
            // Recursively search for WKWebView and make it first responder
            // Use a small delay to ensure views are ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.findAndFocusWebView(in: window.contentView)
            }
        }
    }
    
    private func findAndFocusWebView(in view: NSView?) {
        guard let view = view else { return }
        
        // Check if this view is a WKWebView
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
            window.title = "Apple AI"
            window.isReleasedWhenClosed = false // Important: Don't release window when closed
            window.level = .normal
            
            // Set collection behavior to ensure it appears on current space
            window.collectionBehavior = [.moveToActiveSpace, .transient]
            
            // Enable keyboard event handling
            window.acceptsMouseMovedEvents = true
            window.isMovable = true
            
            // Critical for keyboard input
            window.initialFirstResponder = nil // Let SwiftUI handle first responder
            window.allowsToolTipsWhenApplicationIsInactive = true
            window.hidesOnDeactivate = false
            
            // Set the window delegate to handle close button
            window.delegate = self
            
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
        
        // Attempt to set focus to the webview after a short delay to ensure all views are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let contentView = window.contentView {
                // Try to find the WKWebView within the view hierarchy and make it first responder
                self.makeWebViewFirstResponder(contentView)
            }
        }
    }
    
    // Helper method to find a WKWebView in the view hierarchy and make it first responder
    private func makeWebViewFirstResponder(_ view: NSView) {
        // Check if this view is a WKWebView or contains "WebView" in its class name
        if NSStringFromClass(type(of: view)).contains("WKWebView") {
            if let window = view.window {
                window.makeFirstResponder(view)
                return
            }
        }
        
        // Recursively search through subviews
        for subview in view.subviews {
            makeWebViewFirstResponder(subview)
        }
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
}

// Add NSWindowDelegate extension to MenuBarManager
extension MenuBarManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
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
    func windowShouldClose(_ sender: NSWindow) -> Bool {
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
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        // Always prevent zoom for our popup window
        if window == popupWindow {
            return false
        }
        return true // Allow zoom for other windows
    }
} 