import SwiftUI

struct ProSupportView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Support")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Pro Support Available")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Priority email support")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Community Support")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for priority support")
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
