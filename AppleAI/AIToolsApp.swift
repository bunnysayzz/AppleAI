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
    private var menuBarManager: MenuBarManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (menu bar app)
        NSApp.setActivationPolicy(.accessory)
        
        // Create and setup the menu bar manager
        menuBarManager = MenuBarManager()
        menuBarManager.setup()
        
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
} 