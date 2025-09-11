import SwiftUI

struct ProAdvancedAnalyticsView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Advanced Analytics")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Detailed Analytics")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Usage patterns, insights")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Analytics")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for detailed analytics")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
