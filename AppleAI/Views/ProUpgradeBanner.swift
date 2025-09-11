import SwiftUI

struct ProUpgradeBanner: View {
    @ObservedObject var proManager = ProManager.shared
    @State private var showUpgradeSheet = false
    
    var body: some View {
        if !proManager.isProUser {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    
                    Text(proManager.getProStatusText())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if proManager.trialDaysRemaining > 0 {
                        Button("Upgrade to Pro") {
                            showUpgradeSheet = true
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .font(.caption)
                        .foregroundColor(.blue)
                    } else {
                        Button("Upgrade Now") {
                            proManager.openUpgradeURL()
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor)),
                    alignment: .bottom
                )
                
                if proManager.isTrialExpired() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                        
                        Text("Trial expired. Upgrade to continue using AppleAi Pro.")
                            .font(.caption2)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                }
            }
        }
    }
}

struct ProUpgradeSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("Upgrade to AppleAi Pro")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Unlock unlimited access to all AI models and premium features")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ProFeatureRow(icon: "infinity", text: "Unlimited AI model access")
                ProFeatureRow(icon: "bolt.fill", text: "Priority processing")
                ProFeatureRow(icon: "lock.fill", text: "Advanced privacy controls")
                ProFeatureRow(icon: "gear", text: "Custom API integrations")
                ProFeatureRow(icon: "sparkles", text: "Exclusive Pro features")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button("Upgrade Now") {
                    proManager.openUpgradeURL()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(6)
            }
        }
        .padding(30)
        .frame(width: 400, height: 500)
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    ProUpgradeBanner()
}
