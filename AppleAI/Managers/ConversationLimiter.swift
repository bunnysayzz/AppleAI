import Foundation

class ConversationLimiter: ObservableObject {
    static let shared = ConversationLimiter()
    private let proManager = ProManager.shared
    private let maxConversationsKey = "maxConversations"
    private let conversationCountKey = "conversationCount"
    
    @Published var conversationCount: Int = 0
    @Published var maxConversations: Int = 10
    
    private init() {
        loadConversationData()
    }
    
    private func loadConversationData() {
        conversationCount = UserDefaults.standard.integer(forKey: conversationCountKey)
        maxConversations = UserDefaults.standard.integer(forKey: maxConversationsKey)
        
        if maxConversations == 0 {
            maxConversations = proManager.isProUser ? 999999 : 10
            UserDefaults.standard.set(maxConversations, forKey: maxConversationsKey)
        }
    }
    
    func canStartNewConversation() -> Bool {
        if proManager.isProUser {
            return true
        }
        return conversationCount < maxConversations
    }
    
    func incrementConversationCount() {
        if !proManager.isProUser {
            conversationCount += 1
            UserDefaults.standard.set(conversationCount, forKey: conversationCountKey)
        }
    }
    
    func getConversationLimitText() -> String {
        if proManager.isProUser {
            return "Unlimited conversations"
        } else {
            return "\(conversationCount)/\(maxConversations) conversations used"
        }
    }
    
    func resetConversationCount() {
        conversationCount = 0
        UserDefaults.standard.set(conversationCount, forKey: conversationCountKey)
    }
}
