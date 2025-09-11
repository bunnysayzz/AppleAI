import SwiftUI

struct ProSyncView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.purple)
                    .font(.system(size: 12))
                
                Text("Sync")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Real-time Sync")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Sync across all devices")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Local Sync Only")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for real-time sync")
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
