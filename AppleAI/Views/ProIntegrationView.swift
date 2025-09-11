import SwiftUI

struct ProIntegrationView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Integrations")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Full Integrations")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Connect with 100+ apps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Limited Integrations")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for full integrations")
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
