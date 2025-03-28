import SwiftUI
import WebKit

struct CompactChatView: View {
    @State private var selectedService: AIService
    @State private var isLoading = true
    @StateObject private var preferences = PreferencesManager.shared
    let services: [AIService]
    let closeAction: () -> Void
    
    init(services: [AIService] = aiServices, closeAction: @escaping () -> Void) {
        self.services = services
        self.closeAction = closeAction
        // Set initial selected service
        _selectedService = State(initialValue: services.first!)
    }
    
    // Initialize with a specific service
    init(initialService: AIService, services: [AIService] = aiServices, closeAction: @escaping () -> Void) {
        self.services = services
        self.closeAction = closeAction
        _selectedService = State(initialValue: initialService)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with service selector icons
            HStack(spacing: 0) {
                // Horizontal icons for service selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(services) { service in
                            ServiceIconButton(
                                service: service,
                                isSelected: service.id == selectedService.id,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedService = service
                                    }
                                    // When service changes, ensure we refocus the webview after a short delay
                                    ensureWebViewFocus(delay: 0.5)
                                }
                            )
                            .id(service.id) // Ensure ForEach updates properly
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 40)
                
                Spacer()
                
                // Pin button removed - now in title bar
            }
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Service indicator bar
            Rectangle()
                .frame(height: 2)
                .foregroundColor(selectedService.color)
            
            // Web view for the selected service with focus handling
            PersistentWebView(service: selectedService, isLoading: $isLoading)
                .background(KeyboardFocusModifier(onAppear: {
                    // When web view appears, set up a delayed action to focus the view
                    ensureWebViewFocus(delay: 0.5)
                }))
        }
        .frame(width: 400, height: 600)
        .onAppear {
            // Set up periodic focus checks
            setupPeriodicFocusCheck()
            // Ensure focus immediately
            ensureWebViewFocus(delay: 0.2)
        }
    }
    
    // Function to periodically check and ensure focus is on the webview
    private func setupPeriodicFocusCheck() {
        // Create a timer that checks focus every 1 second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard let window = NSApplication.shared.keyWindow,
                  window.isVisible else {
                return
            }
            
            // Check if the window is key and if first responder is a webview
            if window.isKeyWindow {
                if let firstResponder = window.firstResponder {
                    let className = NSStringFromClass(type(of: firstResponder))
                    // If the first responder is not a WKWebView or KeyboardResponderView, try to focus the webview
                    if !className.contains("WKWebView") && !className.contains("KeyboardResponderView") {
                        ensureWebViewFocus(delay: 0.0)
                    }
                } else {
                    // If there's no first responder, try to focus the webview
                    ensureWebViewFocus(delay: 0.0)
                }
            }
        }
    }
    
    // Enhanced function to help focus the web view with multiple attempts
    private func ensureWebViewFocus(delay: TimeInterval) {
        // Initial attempt with the specified delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            focusWebView()
            
            // Make additional attempts with increasing delays to handle race conditions
            // This helps when the WebView might not be fully loaded yet
            let additionalDelays: [TimeInterval] = [0.3, 0.7, 1.0]
            for (index, additionalDelay) in additionalDelays.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + additionalDelay) {
                    focusWebView()
                    
                    // On the last attempt, use an alternative focus method as a fallback
                    if index == additionalDelays.count - 1 {
                        alternativeFocusMethod()
                    }
                }
            }
        }
    }
    
    // Function to help focus the web view - try to find any WKWebView
    private func focusWebView() {
        guard let window = NSApplication.shared.keyWindow else { return }
        
        // Find any WKWebView in the view hierarchy and make it first responder
        func findAndFocusWebView(in view: NSView) -> Bool {
            // Check if this view is a KeyboardResponderView first (preferred)
            if NSStringFromClass(type(of: view)).contains("KeyboardResponderView") {
                window.makeFirstResponder(view)
                return true
            }
            
            // Otherwise check if it's a WKWebView
            if NSStringFromClass(type(of: view)).contains("WKWebView") {
                window.makeFirstResponder(view)
                return true
            }
            
            // Recursively check subviews
            for subview in view.subviews {
                if findAndFocusWebView(in: subview) {
                    return true
                }
            }
            
            return false
        }
        
        // Start searching from the window's content view
        if let contentView = window.contentView {
            _ = findAndFocusWebView(in: contentView)
        }
    }
    
    // Alternative method to focus the webview using the WebViewCache
    private func alternativeFocusMethod() {
        // Get the webview from the cache and focus it directly
        let webView = WebViewCache.shared.getWebView(for: selectedService)
        
        if let window = webView.window {
            window.makeFirstResponder(webView)
            
            // If that doesn't work, try to simulate a click in the webview
            // to activate any input fields
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Calculate center point of webview
                let centerPoint = NSPoint(
                    x: webView.bounds.midX,
                    y: webView.bounds.midY
                )
                
                // Convert to window coordinates
                let windowPoint = webView.convert(centerPoint, to: nil)
                
                // Create a synthetic mouse event
                let mouseDownEvent = NSEvent.mouseEvent(
                    with: .leftMouseDown,
                    location: windowPoint,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 0
                )
                
                if let mouseDownEvent = mouseDownEvent {
                    webView.mouseDown(with: mouseDownEvent)
                    
                    // Create a matching mouse up event
                    let mouseUpEvent = NSEvent.mouseEvent(
                        with: .leftMouseUp,
                        location: windowPoint,
                        modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber,
                        context: nil,
                        eventNumber: 0,
                        clickCount: 1,
                        pressure: 0
                    )
                    
                    if let mouseUpEvent = mouseUpEvent {
                        webView.mouseUp(with: mouseUpEvent)
                    }
                }
            }
        }
    }
}

// Keep the service icon button
struct ServiceIconButton: View {
    let service: AIService
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(service.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(isSelected ? service.color : .gray)
                
                Text(service.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(isSelected ? service.color : .gray)
            }
            .frame(width: 58, height: 38)
            .contentShape(Rectangle()) // Improves tap area to entire frame
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? service.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? service.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(BorderlessButtonStyle()) // More responsive than PlainButtonStyle
    }
}

// Helper view modifier for handling keyboard focus
struct KeyboardFocusModifier: NSViewRepresentable {
    let onAppear: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onAppear()
        }
    }
}

// Preview for SwiftUI Canvas
struct CompactChatView_Previews: PreviewProvider {
    static var previews: some View {
        CompactChatView(closeAction: {})
            .frame(width: 400, height: 600)
            .padding()
            .background(Color.gray.opacity(0.2))
            .previewLayout(.sizeThatFits)
    }
} 