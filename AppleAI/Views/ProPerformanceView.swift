import SwiftUI

struct ProPerformanceView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                
                Text("Performance")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Priority Processing")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Faster response times")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Standard Processing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for priority processing")
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
