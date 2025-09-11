import Foundation
import SwiftUI

struct AIService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
    let color: Color
    let isProOnly: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AIService, rhs: AIService) -> Bool {
        return lhs.id == rhs.id
    }
}

// AI Services configuration with Pro limitations
let aiServices: [AIService] = [
    AIService(
        name: "ChatGPT",
        icon: "chatgpt",
        url: URL(string: "https://chat.openai.com")!,
        color: Color(red: 0.25, green: 0.75, blue: 0.5),
        isProOnly: false
    ),
    AIService(
        name: "Claude",
        icon: "claude",
        url: URL(string: "https://claude.ai")!,
        color: Color(red: 0.9, green: 0.4, blue: 0.2),
        isProOnly: false
    ),
    AIService(
        name: "Copilot",
        icon: "copilot",
        url: URL(string: "https://github.com/copilot")!,
        color: Color(red: 0.2, green: 0.2, blue: 0.2),
        isProOnly: false
    ),
    AIService(
        name: "Perplexity",
        icon: "perplexity",
        url: URL(string: "https://perplexity.ai")!,
        color: Color(red: 0.1, green: 0.3, blue: 0.8),
        isProOnly: true
    ),
    AIService(
        name: "DeepSeek",
        icon: "deekseek",
        url: URL(string: "https://chat.deepseek.com")!,
        color: Color(red: 0.6, green: 0.2, blue: 0.8),
        isProOnly: true
    ),
    AIService(
        name: "Grok",
        icon: "grok",
        url: URL(string: "https://x.ai")!,
        color: Color(red: 0.8, green: 0.1, blue: 0.1),
        isProOnly: true
    ),
    AIService(
        name: "Gemini",
        icon: "gemini",
        url: URL(string: "https://gemini.google.com")!,
        color: Color(red: 0.1, green: 0.7, blue: 0.9),
        isProOnly: true
    ),
    AIService(
        name: "Pi",
        icon: "pi",
        url: URL(string: "https://pi.ai")!,
        color: Color(red: 0.9, green: 0.6, blue: 0.1),
        isProOnly: true
    )
]

// Filter services based on Pro status
func getAvailableServices() -> [AIService] {
    let proManager = ProManager.shared
    
    if proManager.isProUser || proManager.canUseAdvancedFeatures() {
        return aiServices
    } else {
        // Trial users only get basic services
        return aiServices.filter { !$0.isProOnly }
    }
}
