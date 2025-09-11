import SwiftUI

struct ProPriorityView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                
                Text("Priority")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Priority Support")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Faster response times")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Standard Support")
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
