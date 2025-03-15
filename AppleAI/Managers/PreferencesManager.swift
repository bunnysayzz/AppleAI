import SwiftUI
import ServiceManagement
import CoreServices

@available(macOS 11.0, *)
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published var openAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(openAtLogin, forKey: "openAtLogin")
            updateLoginItem()
        }
    }
    
    @Published var shortcuts: [String: String] {
        didSet {
            if let encoded = try? JSONEncoder().encode(shortcuts) {
                UserDefaults.standard.set(encoded, forKey: "shortcuts")
            }
        }
    }
    
    private init() {
        self.openAtLogin = UserDefaults.standard.bool(forKey: "openAtLogin")
        
        if let data = UserDefaults.standard.data(forKey: "shortcuts"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.shortcuts = decoded
        } else {
            // Simplified shortcuts - just the toggle window shortcut
            self.shortcuts = [
                "toggleWindow": "⌘⌥O"
            ]
        }
        
        updateLoginItem()
    }
    
    func getShortcut(for key: String) -> String {
        return shortcuts[key] ?? ""
    }
    
    func setShortcut(_ shortcut: String, for key: String) {
        shortcuts[key] = shortcut
    }
    
    func resetToDefaults() {
        // Consistent with the default in init
        shortcuts = [
            "toggleWindow": "⌘⌥O"
        ]
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if openAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Error updating login item:", error)
            }
        } else {
            // For older macOS versions, we'll use the legacy approach
            updateLoginItemLegacy(enabled: openAtLogin)
        }
    }
    
    private func updateLoginItemLegacy(enabled: Bool) {
        guard let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() else {
            print("Failed to create login items list")
            return
        }
        
        if enabled {
            guard let bundleURL = Bundle.main.bundleURL as CFURL? else {
                print("Failed to get bundle URL")
                return
            }
            LSSharedFileListInsertItemURL(loginItems,
                                        kLSSharedFileListItemLast.takeRetainedValue(),
                                        nil,
                                        nil,
                                        bundleURL,
                                        nil,
                                        nil)
        } else {
            guard let snapshot = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem] else {
                print("Failed to get login items snapshot")
                return
            }
            
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            for item in snapshot {
                if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL?,
                   itemURL.bundleIdentifier == bundleID {
                    LSSharedFileListItemRemove(loginItems, item)
                }
            }
        }
    }
}

private extension URL {
    var bundleIdentifier: String? {
        if let bundle = Bundle(url: self) {
            return bundle.bundleIdentifier
        }
        return nil
    }
} 