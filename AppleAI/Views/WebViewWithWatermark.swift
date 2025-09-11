import SwiftUI

struct WebViewWithWatermark: View {
    let service: AIService
    @Binding var isLoading: Bool
    
    var body: some View {
        ZStack {
            // Pro service limiter for Pro-only services
            ProServiceLimiter(service: service)
            PersistentWebView(service: service, isLoading: $isLoading)
            
            // Pro watermark overlay
            ProWatermark()
            // Pro screenshot watermark
            ProScreenshotWatermark()
        }
    }
}
