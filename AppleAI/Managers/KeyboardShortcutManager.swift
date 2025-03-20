import AppKit
import Carbon.HIToolbox

class KeyboardShortcutManager {
    private var menuBarManager: MenuBarManager
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID()
    private let preferences = PreferencesManager.shared
    
    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
        
        // Setup hotkey ID with our custom signature
        hotKeyID.signature = fourCharCode("AIAI")
        hotKeyID.id = 1
        
        setupShortcuts()
    }
    
    deinit {
        unregisterGlobalHotKey()
        
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }
    
    private func setupShortcuts() {
        // Register the global Command+E hotkey using Carbon API
        registerGlobalHotKey()
        
        // Set up local event monitoring for Command+Option+Number shortcuts (service shortcuts)
        setupServiceShortcuts()
    }
    
    private func setupServiceShortcuts() {
        // Monitor for local keyboard events for service switching
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleServiceHotKeys(event) == true {
                return nil // Consume the event
            }
            return event // Pass the event along
        }
        
        // Also add global monitor for when app is not in focus
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleServiceHotKeys(event)
        }
    }
    
    private func handleServiceHotKeys(_ event: NSEvent) -> Bool {
        // Check for Command+Option+number shortcuts for service switching
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
                    return true // Indicate the event was handled
                }
            }
        }
        
        return false
    }
    
    private func hotKeyHandler(eventHandlerCallRef: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
        // Extract the hotkey ID from the event
        var hkID = EventHotKeyID()
        let error = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hkID
        )
        
        if error == noErr {
            // We've received a hotkey event with our signature and ID
            if hkID.signature == self.hotKeyID.signature && hkID.id == self.hotKeyID.id {
                // Perform the toggle action on the main thread
                DispatchQueue.main.async { [weak self] in
                    self?.menuBarManager.togglePopupWindow()
                }
            }
        }
        
        return noErr
    }
    
    private func registerGlobalHotKey() {
        // Unregister any existing hotkey
        unregisterGlobalHotKey()
        
        // Define the Command+E keycode and modifiers
        let keyCode = UInt32(kVK_ANSI_E)
        let modifiers = UInt32(cmdKey)
        
        // Create a callback function that can be passed to Carbon
        let eventHandler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            // Extract the hotkey ID from the event
            var hkID = EventHotKeyID()
            let error = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            
            if error == noErr {
                let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                if hkID.signature == manager.hotKeyID.signature && hkID.id == manager.hotKeyID.id {
                    // Perform the toggle action on the main thread
                    DispatchQueue.main.async {
                        manager.menuBarManager.togglePopupWindow()
                    }
                }
            }
            
            return noErr
        }
        
        // Install the event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                    eventKind: OSType(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        
        let err = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        
        if err == noErr {
            // Now register the hotkey
            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            if status != noErr {
                print("Error registering hotkey: \(status)")
            }
        } else {
            print("Error installing event handler: \(err)")
        }
    }
    
    private func unregisterGlobalHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
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
    
    // Helper method to directly toggle the popup window
    @objc func togglePopupWindow() {
        menuBarManager.togglePopupWindow()
    }
    
    // Convert a four character string to a FourCharCode
    private func fourCharCode(_ string: String) -> FourCharCode {
        assert(string.count == 4, "String length must be exactly 4")
        var result: FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}