import SwiftUI

struct ProConsultingView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Consulting")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Expert Consulting")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("1-on-1 expert sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Self-Service")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for expert consulting")
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
