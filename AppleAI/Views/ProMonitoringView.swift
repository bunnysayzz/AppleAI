import SwiftUI

struct ProMonitoringView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Monitoring")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Advanced Monitoring")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Real-time alerts, logs")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Monitoring")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for advanced monitoring")
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
