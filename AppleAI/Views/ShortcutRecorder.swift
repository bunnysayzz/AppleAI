import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    let label: String
    @Binding var shortcut: String
    @State private var isRecording = false
    @State private var localShortcut: String = ""
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(isRecording ? "Recording..." : (shortcut.isEmpty ? "Click to Record" : shortcut))
                    .frame(width: 150, alignment: .center)
            }
            .buttonStyle(.bordered)
            .background(isRecording ? Color.red.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            
            if !shortcut.isEmpty {
                Button(action: {
                    shortcut = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear {
            localShortcut = shortcut
        }
        .onChange(of: shortcut) { newValue in
            localShortcut = newValue
        }
    }
    
    private func startRecording() {
        isRecording = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        shortcut = localShortcut
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        var shortcutString = ""
        
        if event.modifierFlags.contains(.command) {
            shortcutString += "⌘"
        }
        if event.modifierFlags.contains(.option) {
            shortcutString += "⌥"
        }
        if event.modifierFlags.contains(.shift) {
            shortcutString += "⇧"
        }
        if event.modifierFlags.contains(.control) {
            shortcutString += "⌃"
        }
        
        // Handle special keys directly using keyCode
        switch event.keyCode {
        case 36: // Return
            shortcutString += "↩"
        case 48: // Tab
            shortcutString += "⇥"
        case 49: // Space
            shortcutString += "Space"
        case 51: // Delete
            shortcutString += "⌫"
        case 53: // Escape
            shortcutString += "⎋"
        case 123: // Left Arrow
            shortcutString += "←"
        case 124: // Right Arrow
            shortcutString += "→"
        case 125: // Down Arrow
            shortcutString += "↓"
        case 126: // Up Arrow
            shortcutString += "↑"
        default:
            if let characters = event.charactersIgnoringModifiers?.uppercased() {
                shortcutString += characters
            }
        }
        
        localShortcut = shortcutString
        stopRecording()
    }
}

#Preview {
    ShortcutRecorder(label: "Test Shortcut", shortcut: .constant("⌘⌥T"))
}

// Helper view to handle keyboard events
struct ShortcutRecorderController: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: String
    @Binding var finalShortcut: String
    
    func makeNSView(context: Context) -> NSView {
        let view = RecorderView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? RecorderView {
            view.isRecording = isRecording
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ShortcutRecorderController
        
        init(_ parent: ShortcutRecorderController) {
            self.parent = parent
        }
        
        func recordedShortcut(_ shortcut: String) {
            parent.shortcut = shortcut
            parent.finalShortcut = shortcut
            parent.isRecording = false
        }
    }
}

// Custom NSView to handle keyboard events
class RecorderView: NSView {
    weak var delegate: ShortcutRecorderController.Coordinator?
    var isRecording = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        
        var modifierString = ""
        
        if event.modifierFlags.contains(.command) { modifierString += "⌘" }
        if event.modifierFlags.contains(.option) { modifierString += "⌥" }
        if event.modifierFlags.contains(.shift) { modifierString += "⇧" }
        if event.modifierFlags.contains(.control) { modifierString += "⌃" }
        
        // Get the key character
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        
        // Only record if modifiers are used and it's a valid key
        if !modifierString.isEmpty && !key.isEmpty {
            delegate?.recordedShortcut(modifierString + key)
        }
    }
} 