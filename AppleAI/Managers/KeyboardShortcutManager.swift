import AppKit
import Carbon.HIToolbox

class KeyboardShortcutManager {
    private var menuBarManager: MenuBarManager
    private var eventMonitor: Any?
    private let preferences = PreferencesManager.shared
    
    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
        setupGlobalShortcuts()
    }
    
    private func setupGlobalShortcuts() {
        // Monitor for keyboard events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        // Skip processing if the event is coming from a text field or web view
        if let firstResponder = NSApplication.shared.keyWindow?.firstResponder {
            let responderClassName = NSStringFromClass(type(of: firstResponder))
            if responderClassName.contains("TextField") || 
               responderClassName.contains("WKWebView") ||
               responderClassName.contains("NSText") {
                // Don't intercept keyboard shortcuts if we're in a text field or web view
                // This allows normal typing in these controls
                return
            }
        }
        
        // Check for Command+Option+number shortcuts
        if event.modifierFlags.contains([.command, .option]) {
            // Get the number key pressed (1-9 for different AI services)
            if let number = getNumberFromKeyCode(event.keyCode), number >= 1 && number <= 9 {
                // Get the corresponding service (if available)
                let index = number - 1
                if index < aiServices.count {
                    let service = aiServices[index]
                    
                    // Post a notification to open this service
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenAIService"),
                        object: nil,
                        userInfo: ["service": service]
                    )
                }
            }
            
            // Get the toggle shortcut from preferences
            let toggleShortcut = preferences.getShortcut(for: "toggleWindow")
            
            // Check if the current key event matches the toggle shortcut
            if isMatchingShortcut(event: event, shortcutString: toggleShortcut) {
                togglePopupWindow()
            }
        }
    }
    
    private func togglePopupWindow() {
        // Use the selector directly
        menuBarManager.perform(#selector(MenuBarManager.togglePopupWindow))
    }
    
    private func getNumberFromKeyCode(_ keyCode: UInt16) -> Int? {
        // Map key codes to numbers
        switch keyCode {
        case UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_Keypad1): return 1
        case UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_Keypad2): return 2
        case UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_Keypad3): return 3
        case UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_Keypad4): return 4
        case UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_Keypad5): return 5
        case UInt16(kVK_ANSI_6), UInt16(kVK_ANSI_Keypad6): return 6
        case UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_Keypad7): return 7
        case UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_Keypad8): return 8
        case UInt16(kVK_ANSI_9), UInt16(kVK_ANSI_Keypad9): return 9
        case UInt16(kVK_ANSI_0), UInt16(kVK_ANSI_Keypad0): return 10  // For 10th service if needed
        default: return nil
        }
    }
    
    // Helper function to check if an event matches a shortcut string
    private func isMatchingShortcut(event: NSEvent, shortcutString: String) -> Bool {
        // Parse the shortcut string
        var key: String = ""
        var useCommand = false
        var useOption = false
        var useControl = false
        var useShift = false
        
        // Check for common modifiers in the shortcut string
        useCommand = shortcutString.contains("⌘")
        useOption = shortcutString.contains("⌥")
        useControl = shortcutString.contains("⌃")
        useShift = shortcutString.contains("⇧")
        
        // Extract the key character (last character in the string)
        if let lastChar = shortcutString.last {
            key = String(lastChar)
        }
        
        // Check if modifiers match
        let modifiers = event.modifierFlags
        if useCommand != modifiers.contains(.command) ||
           useOption != modifiers.contains(.option) ||
           useControl != modifiers.contains(.control) ||
           useShift != modifiers.contains(.shift) {
            return false
        }
        
        // Match common keys
        switch key {
        case "O":
            return event.keyCode == UInt16(kVK_ANSI_O)
        case " ", "Space":
            return event.keyCode == UInt16(kVK_Space)
        case "↩", "Return":
            return event.keyCode == UInt16(kVK_Return)
        case "⇥", "Tab":
            return event.keyCode == UInt16(kVK_Tab)
        default:
            // Check for alphanumeric keys
            if key.count == 1, let char = key.first, char.isLetter || char.isNumber {
                let keyChar = key.uppercased()
                switch keyChar {
                case "A": return event.keyCode == UInt16(kVK_ANSI_A)
                case "B": return event.keyCode == UInt16(kVK_ANSI_B)
                case "C": return event.keyCode == UInt16(kVK_ANSI_C)
                case "D": return event.keyCode == UInt16(kVK_ANSI_D)
                case "E": return event.keyCode == UInt16(kVK_ANSI_E)
                case "F": return event.keyCode == UInt16(kVK_ANSI_F)
                case "G": return event.keyCode == UInt16(kVK_ANSI_G)
                case "H": return event.keyCode == UInt16(kVK_ANSI_H)
                case "I": return event.keyCode == UInt16(kVK_ANSI_I)
                case "J": return event.keyCode == UInt16(kVK_ANSI_J)
                case "K": return event.keyCode == UInt16(kVK_ANSI_K)
                case "L": return event.keyCode == UInt16(kVK_ANSI_L)
                case "M": return event.keyCode == UInt16(kVK_ANSI_M)
                case "N": return event.keyCode == UInt16(kVK_ANSI_N)
                case "O": return event.keyCode == UInt16(kVK_ANSI_O)
                case "P": return event.keyCode == UInt16(kVK_ANSI_P)
                case "Q": return event.keyCode == UInt16(kVK_ANSI_Q)
                case "R": return event.keyCode == UInt16(kVK_ANSI_R)
                case "S": return event.keyCode == UInt16(kVK_ANSI_S)
                case "T": return event.keyCode == UInt16(kVK_ANSI_T)
                case "U": return event.keyCode == UInt16(kVK_ANSI_U)
                case "V": return event.keyCode == UInt16(kVK_ANSI_V)
                case "W": return event.keyCode == UInt16(kVK_ANSI_W)
                case "X": return event.keyCode == UInt16(kVK_ANSI_X)
                case "Y": return event.keyCode == UInt16(kVK_ANSI_Y)
                case "Z": return event.keyCode == UInt16(kVK_ANSI_Z)
                case "0": return event.keyCode == UInt16(kVK_ANSI_0)
                case "1": return event.keyCode == UInt16(kVK_ANSI_1)
                case "2": return event.keyCode == UInt16(kVK_ANSI_2)
                case "3": return event.keyCode == UInt16(kVK_ANSI_3)
                case "4": return event.keyCode == UInt16(kVK_ANSI_4)
                case "5": return event.keyCode == UInt16(kVK_ANSI_5)
                case "6": return event.keyCode == UInt16(kVK_ANSI_6)
                case "7": return event.keyCode == UInt16(kVK_ANSI_7)
                case "8": return event.keyCode == UInt16(kVK_ANSI_8)
                case "9": return event.keyCode == UInt16(kVK_ANSI_9)
                default: return false
                }
            }
            return false
        }
    }
    
    deinit {
        // Remove the event monitor when this object is deallocated
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
} 