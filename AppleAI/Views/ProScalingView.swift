import SwiftUI

struct ProScalingView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.purple)
                    .font(.system(size: 12))
                
                Text("Scaling")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Unlimited Scaling")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Handle any workload")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Limited Scaling")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for unlimited scaling")
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
