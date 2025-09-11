import SwiftUI

struct ProUsageLimitView: View {
    @ObservedObject var proManager = ProManager.shared
    @ObservedObject var dailyLimiter = DailyUsageLimiter.shared
    
    var body: some View {
        if !proManager.isProUser && !dailyLimiter.canUseApp() {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                
                Text("Daily Usage Limit Reached")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("You've reached your daily limit of \(dailyLimiter.maxDailyUsage) uses.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("Upgrade to Pro for unlimited daily usage")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                
                Button("Upgrade to Pro") {
                    proManager.openUpgradeURL()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(6)
                
                Text("Usage resets tomorrow")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        } else {
            EmptyView()
        }
    }
}
