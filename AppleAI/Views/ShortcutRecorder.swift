import SwiftUI

// Simplified ShortcutRecorder that only displays a fixed shortcut without recording capability
struct ShortcutRecorder: View {
    let label: String
    @Binding var shortcut: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            
            // Display the shortcut without any interaction
            Text(shortcut.isEmpty ? "None" : shortcut)
                .frame(width: 150, alignment: .center)
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

#Preview {
    ShortcutRecorder(label: "Toggle Window", shortcut: .constant("⌘E"))
} 