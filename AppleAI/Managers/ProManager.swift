import Foundation
import SwiftUI

class ProManager: ObservableObject {
    static let shared = ProManager()
    
    @Published var isProUser: Bool = false
    @Published var trialDaysRemaining: Int = 7
    @Published var hasShownUpgradePrompt: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let trialStartDateKey = "trialStartDate"
    private let isProUserKey = "isProUser"
    private let hasShownUpgradePromptKey = "hasShownUpgradePrompt"
    
    private init() {
        checkFirstLaunch()
        loadProStatus()
        calculateTrialDays()
    }
    
    private func loadProStatus() {
        isProUser = userDefaults.bool(forKey: isProUserKey)
        hasShownUpgradePrompt = userDefaults.bool(forKey: hasShownUpgradePromptKey)
        
        // If no trial start date is set, set it now
        if userDefaults.object(forKey: trialStartDateKey) == nil {
            userDefaults.set(Date(), forKey: trialStartDateKey)
        }
    }
    
    private func calculateTrialDays() {
        guard let trialStartDate = userDefaults.object(forKey: trialStartDateKey) as? Date else {
            trialDaysRemaining = 7
            return
        }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
        trialDaysRemaining = max(0, 7 - daysSinceStart)
    }
    
    func isTrialExpired() -> Bool {
        return !isProUser && trialDaysRemaining <= 0
    }
    
    func shouldShowUpgradePrompt() -> Bool {
        return !isProUser && !hasShownUpgradePrompt && trialDaysRemaining <= 3
    }
    
    func markUpgradePromptShown() {
        hasShownUpgradePrompt = true
        userDefaults.set(true, forKey: hasShownUpgradePromptKey)
    }
    
    func upgradeToPro() {
        isProUser = true
        userDefaults.set(true, forKey: isProUserKey)
    }
    
    func canUseAdvancedFeatures() -> Bool {
        return isProUser || trialDaysRemaining > 0
    }
    
    func getProStatusText() -> String {
        if isProUser {
            return "Pro User"
        } else if trialDaysRemaining > 0 {
            return "Trial: \(trialDaysRemaining) days left"
        } else {
            return "Trial Expired"
        }
    }
    
    func openUpgradeURL() {
    }
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = userDefaults.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            userDefaults.set(true, forKey: "hasLaunchedBefore")
            // Reset trial start date for new users
            userDefaults.set(Date(), forKey: trialStartDateKey)
        }
    }
        if let url = URL(string: "https://www.theappleai.tech/pricing") {
            NSWorkspace.shared.open(url)
        }
    }
}
