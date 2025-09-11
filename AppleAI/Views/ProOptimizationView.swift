import SwiftUI

struct ProOptimizationView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                Text("Optimization")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Advanced Optimization")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("AI-powered performance tuning")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Optimization")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for advanced optimization")
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
