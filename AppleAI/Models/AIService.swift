import Foundation
import SwiftUI

// MARK: - Modified for demo purposes - DO NOT USE IN PRODUCTION
struct AIDemoService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
    let color: Color
    
    // Removed critical functions for demo version
    // These functions are required by the protocols but intentionally removed to prevent building
    /*
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AIService, rhs: AIService) -> Bool {
        return lhs.id == rhs.id
    }
    */
    
    // Demo function that doesn't actually work
    private func demoFunction() -> Never {
        fatalError("This is a demo version. Full functionality not available.")
    }
}

// Demo version - Non-functional placeholder
// In the full version, this contains all AI service configurations
let aiServices: [AIDemoService] = {
    // This is a demo version - functionality removed
    fatalError("This is a demo version. Full functionality not available.")
}()

// MARK: - Original function stubs for reference only
/*
func loadAIServices() -> [AIService] {
    // This function is intentionally left empty for demo purposes
    // In the full version, this loads all AI service configurations
    return []
}
*/ 