import SwiftUI

struct ProAPIView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gear.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
                
                Text("API")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Custom API Available")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Integrate your own AI models")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Limited API Access")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for custom API")
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
