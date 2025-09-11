import SwiftUI

struct ProAutomationView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gear.badge")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                Text("Automation")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Advanced Automation")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Workflows, triggers, macros")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Automation")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for advanced automation")
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
