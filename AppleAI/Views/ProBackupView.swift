import SwiftUI

struct ProBackupView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Backup")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Cloud Backup Available")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Automatic sync across devices")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Local Backup Only")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for cloud backup")
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
