import SwiftUI

struct ProCollaborationView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 12))
                
                Text("Collaboration")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Team Collaboration")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Share conversations with team")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Individual Use Only")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for team features")
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
