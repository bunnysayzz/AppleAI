import SwiftUI

struct PreferencesView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Preferences")
                .font(.title)
                .padding(.top)
            
            Toggle("Open at Login", isOn: $preferences.openAtLogin)
                .padding(.horizontal)
            
            Toggle("Always on top", isOn: $preferences.alwaysOnTop)
                .padding(.horizontal)
                .help("When enabled, the app window won't hide when clicking outside")
            
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    // Static keyboard shortcut display instead of recorder
                    HStack {
                        Text("Toggle Window")
                            .frame(width: 100, alignment: .leading)
                        
                        Text("⌘E")
                            .frame(width: 150, alignment: .center)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding()
            }
            .padding(.horizontal)
            
            // Developer section
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    HStack {
                        Text("Azhar")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            openURL(URL(string: "https://github.com/bunnysayzz")!)
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("GitHub")
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding()
            }
            .padding(.horizontal)
            
            // Removed the "Reset to Default" button since shortcuts are fixed
            Spacer()
        }
        .frame(width: 400, height: 350)
    }
}

#Preview {
    PreferencesView()
} 