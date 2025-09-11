import Foundation

class DailyUsageLimiter: ObservableObject {
    static let shared = DailyUsageLimiter()
    private let proManager = ProManager.shared
    private let dailyUsageKey = "dailyUsage"
    private let lastUsageDateKey = "lastUsageDate"
    private let maxDailyUsageKey = "maxDailyUsage"
    
    @Published var dailyUsage: Int = 0
    @Published var maxDailyUsage: Int = 5
    
    private init() {
        loadDailyUsageData()
    }
    
    private func loadDailyUsageData() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastUsageDate = UserDefaults.standard.object(forKey: lastUsageDateKey) as? Date ?? Date.distantPast
        
        // Reset daily usage if it's a new day
        if !Calendar.current.isDate(lastUsageDate, inSameDayAs: today) {
            dailyUsage = 0
            UserDefaults.standard.set(dailyUsage, forKey: dailyUsageKey)
            UserDefaults.standard.set(today, forKey: lastUsageDateKey)
        } else {
            dailyUsage = UserDefaults.standard.integer(forKey: dailyUsageKey)
        }
        
        maxDailyUsage = UserDefaults.standard.integer(forKey: maxDailyUsageKey)
        if maxDailyUsage == 0 {
            maxDailyUsage = proManager.isProUser ? 999999 : 5
            UserDefaults.standard.set(maxDailyUsage, forKey: maxDailyUsageKey)
        }
    }
    
    func canUseApp() -> Bool {
        if proManager.isProUser {
            return true
        }
        return dailyUsage < maxDailyUsage
    }
    
    func incrementUsage() {
        if !proManager.isProUser {
            dailyUsage += 1
            UserDefaults.standard.set(dailyUsage, forKey: dailyUsageKey)
            UserDefaults.standard.set(Date(), forKey: lastUsageDateKey)
        }
    }
    
    func getDailyUsageText() -> String {
        if proManager.isProUser {
            return "Unlimited daily usage"
        } else {
            return "\(dailyUsage)/\(maxDailyUsage) uses today"
        }
    }
    
    func resetDailyUsage() {
        dailyUsage = 0
        UserDefaults.standard.set(dailyUsage, forKey: dailyUsageKey)
        UserDefaults.standard.set(Date(), forKey: lastUsageDateKey)
    }
}
