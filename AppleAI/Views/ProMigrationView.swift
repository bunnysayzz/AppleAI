import SwiftUI

struct ProMigrationView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.right.arrow.left")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                Text("Migration")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Seamless Migration")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Automated data migration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Manual Migration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for seamless migration")
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
