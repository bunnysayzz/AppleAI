import SwiftUI

struct PreferencesView: View {
    @StateObject private var preferences = PreferencesManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Preferences")
                .font(.title)
                .padding(.top)
            
            Toggle("Open at Login", isOn: $preferences.openAtLogin)
                .padding(.horizontal)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .padding(.bottom, 5)
                    ShortcutRecorder(label: "Toggle Window", shortcut: binding(for: "toggleWindow"))
                }
                .padding()
            }
            .padding(.horizontal)
            
            Button("Reset to Default") {
                resetToDefaults()
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 300)
    }
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { preferences.shortcuts[key] ?? "" },
            set: { preferences.shortcuts[key] = $0 }
        )
    }
    
    private func resetToDefaults() {
        preferences.shortcuts = [
            "toggleWindow": "⌘⌥O"
        ]
    }
}

#Preview {
    PreferencesView()
} 