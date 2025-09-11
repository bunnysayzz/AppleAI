import SwiftUI

struct ProAnalyticsView: View {
    @ObservedObject var proManager = ProManager.shared
    @State private var totalSessions = 0
    @State private var favoriteService = "ChatGPT"
    
    var body: some View {
        if !proManager.isProUser {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    
                    Text("Usage Analytics")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total sessions: \(totalSessions)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Favorite: \(favoriteService)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Upgrade for detailed analytics")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .onAppear {
                loadAnalytics()
            }
        }
    }
    
    private func loadAnalytics() {
        totalSessions = UserDefaults.standard.integer(forKey: "totalSessions")
        favoriteService = UserDefaults.standard.string(forKey: "favoriteService") ?? "ChatGPT"
    }
}
