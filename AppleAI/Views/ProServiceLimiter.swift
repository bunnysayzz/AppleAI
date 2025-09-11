import SwiftUI

struct ProServiceLimiter: View {
    @ObservedObject var proManager = ProManager.shared
    let service: AIService
    
    var body: some View {
        if service.isProOnly && !proManager.isProUser {
            VStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                
                Text("Pro Feature")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(service.name) is available in AppleAi Pro")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("Pro users get access to:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ProFeatureRow(icon: "infinity", text: "All AI models")
                        ProFeatureRow(icon: "bolt.fill", text: "Priority processing")
                        ProFeatureRow(icon: "lock.fill", text: "Advanced privacy")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Button("Upgrade to Pro") {
                    proManager.openUpgradeURL()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(6)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        } else {
            EmptyView()
        }
    }
}
