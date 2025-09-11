import SwiftUI

struct ProScreenshotWatermark: View {
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        if !proManager.isProUser {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("AppleAi Pro - Trial Version")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}
