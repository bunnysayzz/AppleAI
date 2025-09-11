import SwiftUI

struct ProMaintenanceView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                
                Text("Maintenance")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Proactive Maintenance")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Automated updates, patches")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Manual Maintenance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for proactive maintenance")
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
