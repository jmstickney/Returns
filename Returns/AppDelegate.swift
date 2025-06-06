//
//  AppDelegate.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//

import UIKit
import UserNotifications
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // In AppDelegate.swift or ReturnsApp.swift init
        print("All Info.plist keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "none")")
        print("Shippo API Key: \(Bundle.main.object(forInfoDictionaryKey: "ShippoAPIKey") ?? "not found")")
        
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Setup notification categories
        NotificationManager.shared.setupNotificationCategories()
        
        // Register background tasks
        registerBackgroundTasks()
        
        return true
    }
    
    // MARK: - Background App Refresh
    
    private func registerBackgroundTasks() {
        // Register background app refresh task
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.jstick.Returns.refresh", using: nil) { task in
            print("🔄 BACKGROUND TASK IS RUNNING: \(Date())")
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        print("🔧 Background task registration: \(registered ? "SUCCESS" : "FAILED")")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.jstick.Returns.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh task scheduled")
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 BACKGROUND TASK IS RUNNING: \(Date())")
        
        // Schedule the next background refresh
        scheduleAppRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform background tracking update
        performBackgroundTrackingUpdate { success in
            task.setTaskCompleted(success: success)
        }
    }
    
//    private func performBackgroundTrackingUpdate(completion: @escaping (Bool) -> Void) {
//        // This would typically access your shared ReturnsViewModel
//        // For now, we'll simulate the background update
//        
//        DispatchQueue.global(qos: .background).async {
//            // Simulate checking for tracking updates
//            // In real implementation, you'd:
//            // 1. Get current return items from persistent storage
//            // 2. Check tracking status for items that need updates
//            // 3. Compare with stored status
//            // 4. Send notifications for any changes
//            
//            // Simulate network call
//            Thread.sleep(forTimeInterval: 2)
//            
//            // For demo purposes, randomly decide if there are updates
//            let hasUpdates = Bool.random()
//            
//            if hasUpdates {
//                // Send notification about updates found
//                NotificationManager.shared.scheduleBackgroundRefreshNotification()
//            }
//            
//            DispatchQueue.main.async {
//                completion(true)
//            }
//        }
//    }
    
    private func performBackgroundTrackingUpdate(completion: @escaping (Bool) -> Void) {
        print("🔍 Starting background email scan test...")
        
        // Send immediate notification that background task is running
        let content = UNMutableNotificationContent()
        content.title = "Background Task Running"
        content.body = "📧 Checking for new returns in your email..."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "bg_scan_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("📬 Sent background scan notification")
            }
        }
        
        // Check if Gmail is authenticated
        if !GmailAuthManager.shared.isAuthenticated {
            print("❌ Gmail not authenticated, skipping scan")
            completion(true)
            return
        }
        
        // Perform email scan in background
        DispatchQueue.global(qos: .background).async {
            // Simulate email scanning work
            Thread.sleep(forTimeInterval: 3) // Simulate API call time
            
            DispatchQueue.main.async {
                // Send completion notification
                let completionContent = UNMutableNotificationContent()
                completionContent.title = "Email Scan Complete"
                completionContent.body = "📬 Check for new returns found!"
                completionContent.sound = .default
                
                let completionTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let completionRequest = UNNotificationRequest(
                    identifier: "bg_complete_\(Date().timeIntervalSince1970)",
                    content: completionContent,
                    trigger: completionTrigger
                )
                
                UNUserNotificationCenter.current().add(completionRequest) { error in
                    if let error = error {
                        print("❌ Failed to send completion notification: \(error)")
                    } else {
                        print("📬 Sent scan completion notification")
                    }
                }
                
                completion(true)
            }
        }
    }
    
    // Handle URL scheme callback for OAuth
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Print the URL for debugging
        print("App opened with URL: \(url.absoluteString)")
        
        // The actual handling of the OAuth callback URL will be done by ASWebAuthenticationSession
        // This method just needs to return true to indicate that your app handled the URL
        return true
    }
    
    // MARK: - Notification Delegate Methods
    
    // This method will be called when a notification is received while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // This method will be called when a user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle different notification types
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "tracking_update":
                handleTrackingNotificationTap(userInfo: userInfo, actionIdentifier: response.actionIdentifier)
            case "reminder":
                handleReminderNotificationTap(userInfo: userInfo)
            case "deadline_warning":
                handleDeadlineNotificationTap(userInfo: userInfo)
            case "background_refresh":
                handleBackgroundRefreshNotificationTap()
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    private func handleTrackingNotificationTap(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        guard let itemIDString = userInfo["itemID"] as? String,
              let itemID = UUID(uuidString: itemIDString) else { return }
        
        switch actionIdentifier {
        case "MARK_RECEIVED":
            // Handle marking item as received
            // You'd typically update the item status here
            print("Mark as received tapped for item: \(itemID)")
        case "VIEW_DETAILS", UNNotificationDefaultActionIdentifier:
            // Navigate to item details
            // This would typically use a navigation coordinator or post a notification
            NotificationCenter.default.post(name: .navigateToReturnDetail, object: itemID)
        default:
            break
        }
    }
    
    private func handleReminderNotificationTap(userInfo: [AnyHashable: Any]) {
        if let itemIDString = userInfo["itemID"] as? String,
           let itemID = UUID(uuidString: itemIDString) {
            NotificationCenter.default.post(name: .navigateToReturnDetail, object: itemID)
        }
    }
    
    private func handleDeadlineNotificationTap(userInfo: [AnyHashable: Any]) {
        if let itemIDString = userInfo["itemID"] as? String,
           let itemID = UUID(uuidString: itemIDString) {
            NotificationCenter.default.post(name: .navigateToReturnDetail, object: itemID)
        }
    }
    
    private func handleBackgroundRefreshNotificationTap() {
        // Navigate to main returns list to show updated information
        NotificationCenter.default.post(name: .refreshReturnsList, object: nil)
    }
}

// MARK: - Notification Navigation Constants

extension Notification.Name {
    static let navigateToReturnDetail = Notification.Name("navigateToReturnDetail")
    static let refreshReturnsList = Notification.Name("refreshReturnsList")
}
