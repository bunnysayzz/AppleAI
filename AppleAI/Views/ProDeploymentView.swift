import SwiftUI

struct ProDeploymentView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                Text("Deployment")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Advanced Deployment")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("CI/CD, auto-deployment")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Deployment")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for advanced deployment")
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
