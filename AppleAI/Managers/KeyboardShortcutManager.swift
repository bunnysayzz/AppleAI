import AppKit
import Carbon.HIToolbox

class KeyboardShortcutManager {
    private var menuBarManager: MenuBarManager
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
    }
    
    private func setupShortcuts() {
        // Register the global Command+E hotkey using Carbon API
        registerGlobalHotKey()
        
        // All other shortcuts have been removed
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