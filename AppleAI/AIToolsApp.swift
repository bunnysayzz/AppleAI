import SwiftUI
import AppKit

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (menu bar app)
        NSApp.setActivationPolicy(.accessory)
        
        // Create and setup the menu bar manager
        menuBarManager = MenuBarManager()
        menuBarManager.setup()
        
        // Setup application main menu with keyboard shortcut support
        setupMainMenu()
        
        // Register for global keyboard shortcut at application level
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only handle events when they're not in our webview window
            guard let self = self, let window = event.window else {
                // If no window (global event), only pass through Command+E
                if event.modifierFlags.contains(.command) && 
                   !event.modifierFlags.contains(.option) && 
                   !event.modifierFlags.contains(.control) && 
                   !event.modifierFlags.contains(.shift) &&
                   event.keyCode == UInt16(0x0E) { // E key
                    
                    self?.menuBarManager?.perform(#selector(MenuBarManager.togglePopupWindow))
                    return nil // Consume the event
                }
                
                // For other global key events, let them pass through to prevent app quit
                return event
            }
            
            // For events in our app windows, handle Command+E and pass others through
            // Since we don't have direct access to popupWindow, we'll check if the window is the one we manage
            if let window = event.window, window.title == "Apple AI" {
                // This event is likely in our popup window - it will be handled by the window's monitor
                return event
            } else {
                // Handle Command+E for any window to toggle the popup
                if event.modifierFlags.contains(.command) && 
                   !event.modifierFlags.contains(.option) && 
                   !event.modifierFlags.contains(.control) && 
                   !event.modifierFlags.contains(.shift) &&
                   event.keyCode == UInt16(0x0E) { // E key
                    
                    self.menuBarManager?.perform(#selector(MenuBarManager.togglePopupWindow))
                    return nil // Consume the event
                }
            }
            
            return event // Pass other events through
        }
        
        // Add another monitor for key equivalents (keyboard shortcuts)
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
        
        // Prevent app termination by adding a persistent window
        createPersistentWindow()
        
        // Register for termination notification to manually handle app termination
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
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
    }
    
    // This method is called when the user attempts to quit your app
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // You can perform cleanup here or show confirmation dialogs
        // Return .terminateNow to allow termination, or .terminateCancel to cancel
        return .terminateNow
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