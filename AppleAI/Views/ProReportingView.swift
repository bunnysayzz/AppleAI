import SwiftUI

struct ProReportingView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                
                Text("Reporting")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Advanced Reporting")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Custom reports, exports")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Reporting")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for advanced reporting")
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
