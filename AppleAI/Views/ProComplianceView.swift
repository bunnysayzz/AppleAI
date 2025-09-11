import SwiftUI

struct ProComplianceView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                Text("Compliance")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Full Compliance")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("GDPR, HIPAA, SOC2")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Compliance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for full compliance")
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
