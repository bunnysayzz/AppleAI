import SwiftUI

struct ProStatsView: View {
    @ObservedObject var proManager = ProManager.shared
    @State private var usageCount = 0
    
    var body: some View {
        if !proManager.isProUser {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                    
                    Text("Usage Stats")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Text("Sessions used: \(usageCount)/10")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if usageCount >= 8 {
                    Text("Upgrade to Pro for unlimited access")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .onAppear {
                loadUsageCount()
            }
        }
    }
    
    private func loadUsageCount() {
        usageCount = UserDefaults.standard.integer(forKey: "sessionCount")
    }
    
    private func incrementUsage() {
        usageCount += 1
        UserDefaults.standard.set(usageCount, forKey: "sessionCount")
    }
}
