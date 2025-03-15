import SwiftUI

struct WebViewWindow: View {
    let service: AIService
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            HStack {
                HStack(spacing: 8) {
                    Image(service.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(service.name)
                        .font(.headline)
                }
                .foregroundColor(service.color)
                
                Spacer()
                
                // Add file upload button
                Button(action: {
                    WebViewCache.shared.triggerFileUpload(for: service)
                }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(service.color)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing, 8)
                .help("Attach files")
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            PersistentWebView(service: service, isLoading: $isLoading)
        }
    }
} 