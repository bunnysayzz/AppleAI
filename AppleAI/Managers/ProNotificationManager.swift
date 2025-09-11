import Foundation
import UserNotifications

class ProNotificationManager: ObservableObject {
    static let shared = ProNotificationManager()
    private let proManager = ProManager.shared
    
    private init() {
        requestNotificationPermission()
        scheduleTrialNotifications()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func scheduleTrialNotifications() {
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule notification for 3 days before trial expires
        if proManager.trialDaysRemaining > 3 {
            let content = UNMutableNotificationContent()
            content.title = "AppleAi Pro Trial"
            content.body = "Your trial expires in 3 days. Upgrade to Pro to continue using all features."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval((proManager.trialDaysRemaining - 3) * 24 * 60 * 60), repeats: false)
            let request = UNNotificationRequest(identifier: "trial-3-days", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
        
        // Schedule notification for trial expiration
        if proManager.trialDaysRemaining > 0 {
            let content = UNMutableNotificationContent()
            content.title = "AppleAi Pro Trial Expired"
            content.body = "Your trial has expired. Upgrade to Pro to continue using AppleAi Pro."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(proManager.trialDaysRemaining * 24 * 60 * 60), repeats: false)
            let request = UNNotificationRequest(identifier: "trial-expired", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
    
    func showTrialExpiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Trial Expired"
        alert.informativeText = "Your AppleAi Pro trial has expired. Please upgrade to continue using the app."
        alert.addButton(withTitle: "Upgrade Now")
        alert.addButton(withTitle: "Continue with Limited Features")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            proManager.openUpgradeURL()
        }
    }
}
