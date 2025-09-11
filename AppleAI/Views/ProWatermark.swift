import SwiftUI

struct ProWatermark: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        if !proManager.isProUser {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("AppleAi Pro")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .cornerRadius(4)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}
