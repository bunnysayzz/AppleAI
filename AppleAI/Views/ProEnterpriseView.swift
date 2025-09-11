import SwiftUI

struct ProEnterpriseView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Enterprise")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Enterprise Features")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("SSO, admin controls")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Individual Use")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for enterprise features")
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
