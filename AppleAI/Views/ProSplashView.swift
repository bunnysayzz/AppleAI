import SwiftUI

struct ProSplashView: View {
    @State private var showSplash = true
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        if showSplash {
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Welcome to AppleAi Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your AI assistant hub for macOS")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Text("Trial Version")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("\(proManager.trialDaysRemaining) days remaining")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Button("Get Started") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
                
                Button("Upgrade to Pro") {
                    proManager.openUpgradeURL()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.blue)
                .font(.caption)
            }
            .padding(40)
            .frame(width: 400, height: 500)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        } else {
            EmptyView()
        }
    }
}
