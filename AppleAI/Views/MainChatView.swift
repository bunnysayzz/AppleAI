import SwiftUI
import WebKit

struct MainChatView: View {
    @State private var selectedService: AIService
    @State private var isLoading = true
    let services: [AIService]
    
    init(services: [AIService] = aiServices) {
        self.services = services
        // Set initial selected service
        _selectedService = State(initialValue: services.first!)
    }
    
    // Initialize with a specific service
    init(initialService: AIService, services: [AIService] = aiServices) {
        self.services = services
        _selectedService = State(initialValue: initialService)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with model selector
            HStack {
                Text("Apple AI")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Model selector dropdown
                Picker("", selection: $selectedService) {
                    ForEach(services) { service in
                        HStack {
                            Image(service.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(service.color)
                            Text(service.name)
                        }
                        .tag(service)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Model indicator bar
            HStack {
                Image(selectedService.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
                Text(selectedService.name)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(selectedService.color)
            
            // Web view for the selected service - use PersistentWebView instead
            PersistentWebView(service: selectedService, isLoading: $isLoading)
                // Remove the .id modifier to preserve WebView state
        }
    }
}

// Preview for SwiftUI Canvas
struct MainChatView_Previews: PreviewProvider {
    static var previews: some View {
        MainChatView()
            .frame(width: 800, height: 600)
    }
} 