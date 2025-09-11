import SwiftUI

struct ProCustomizationView: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                
                Text("Customization")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if proManager.isProUser {
                    Text("Full Customization")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Text("Custom shortcuts, layouts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Basic Customization")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for full customization")
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
