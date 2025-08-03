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

// Demo version - Limited functionality
// In the full version, this contains all AI service configurations
let aiServices: [AIService] = {
    // Only include a demo service in the public version
    let demoService = AIService(
        name: "Demo Mode",
        icon: "AILogos/chatgpt",  // Using a single icon for demo
        url: URL(string: "https://example.com")!,  // Dummy URL
        color: Color.gray
    )
    return [demoService]
}() 