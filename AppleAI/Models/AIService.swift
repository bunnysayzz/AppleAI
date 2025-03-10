import Foundation
import SwiftUI

struct AIService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
    let color: Color
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AIService, rhs: AIService) -> Bool {
        return lhs.id == rhs.id
    }
}

// Predefined AI services
let aiServices = [
    AIService(
        name: "ChatGPT",
        icon: "AILogos/chatgpt",
        url: URL(string: "https://chat.openai.com")!,
        color: Color.green
    ),
    AIService(
        name: "Claude",
        icon: "AILogos/claude",
        url: URL(string: "https://claude.ai")!,
        color: Color.purple
    ),
    AIService(
        name: "Copilot",
        icon: "AILogos/copilot",
        url: URL(string: "https://copilot.microsoft.com")!,
        color: Color.blue
    ),
    AIService(
        name: "Perplexity",
        icon: "AILogos/perplexity",
        url: URL(string: "https://www.perplexity.ai")!,
        color: Color.orange
    ),
    AIService(
        name: "DeepSeek",
        icon: "AILogos/deekseek",
        url: URL(string: "https://chat.deepseek.com")!,
        color: Color.red
    ),
    AIService(
        name: "Grok",
        icon: "AILogos/grok",
        url: URL(string: "https://grok.com/?referrer=website")!,
        color: Color(red: 0.0, green: 0.6, blue: 0.9)
    )
] 