import SwiftUI

struct MultiTabView: View {
    @State private var selectedService: AIService
    let services: [AIService]
    
    init(services: [AIService] = aiServices) {
        self.services = services
        // Set initial selected service
        _selectedService = State(initialValue: services.first!)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(services) { service in
                    TabButton(
                        service: service,
                        isSelected: selectedService.id == service.id,
                        action: { selectedService = service }
                    )
                }
                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            // Content area
            WebViewWindow(service: selectedService)
                .transition(.opacity)
                .id(selectedService.id) // Force view recreation when service changes
        }
    }
}

struct TabButton: View {
    let service: AIService
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(service.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(service.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                    service.color.opacity(0.1) : 
                    Color.clear
            )
            .foregroundColor(isSelected ? service.color : .primary)
            .cornerRadius(6)
            .overlay(
                isSelected ?
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(service.color)
                        .offset(y: 13) :
                    nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview for SwiftUI Canvas
struct MultiTabView_Previews: PreviewProvider {
    static var previews: some View {
        MultiTabView()
            .frame(width: 800, height: 600)
    }
} 