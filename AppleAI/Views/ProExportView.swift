import SwiftUI

struct ProExportView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                Text("Export")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Full Export Available")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("PDF, TXT, JSON formats")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Limited Export")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for full export options")
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
