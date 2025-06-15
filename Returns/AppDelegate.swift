import UIKit
import UserNotifications
import BackgroundTasks
import Combine

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static var shared: AppDelegate? {
            return UIApplication.shared.delegate as? AppDelegate
        }
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Debug Info.plist
        print("📱 App Launch - Info.plist Debug:")
        print("All Info.plist keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "none")")
        print("Shippo API Key: \(Bundle.main.object(forInfoDictionaryKey: "ShippoAPIKey") ?? "not found")")
        
        // SEND LAUNCH NOTIFICATION TO VERIFY APPDELEGATE IS CONNECTED
        sendBackgroundDebugNotification("🚀 AppDelegate Launched", body: "AppDelegate didFinishLaunching was called")
        
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Setup notification categories
        NotificationManager.shared.setupNotificationCategories()
        
        // Check background refresh status
        checkBackgroundRefreshStatus()
        
        // REMOVED: Background task registration - now handled by ReturnsApp
        print("📱 Background task registration skipped - handled by ReturnsApp")
        
        return true
    }
    
    // MARK: - Background App Refresh Status Check
    
    private func checkBackgroundRefreshStatus() {
        let status = UIApplication.shared.backgroundRefreshStatus
        
        switch status {
        case .available:
            print("✅ Background App Refresh: Available")
        case .denied:
            print("❌ Background App Refresh: Denied by user - Background tasks will not work")
        case .restricted:
            print("❌ Background App Refresh: Restricted by system")
        @unknown default:
            print("❓ Background App Refresh: Unknown status")
        }
    }
    
    // MARK: - Background Task Registration - DISABLED (handled by ReturnsApp)
    
    /*
    private func registerBackgroundTasks() {
        // This method is now disabled - background task registration
        // is handled by ReturnsApp to avoid duplicate registration
    }
    */
    
    // MARK: - App Lifecycle Events
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 APPDELEGATE: App entered background - manual scheduling disabled")
        
        // SEND IMMEDIATE NOTIFICATION TO CONFIRM THIS METHOD IS CALLED
        sendBackgroundDebugNotification("📱 AppDelegate Background", body: "applicationDidEnterBackground was called (manual scheduling handled by ReturnsApp)")
        
        // REMOVED: scheduleAppRefresh() - now handled by ReturnsApp
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 APPDELEGATE: App entering foreground")
        
        // SEND NOTIFICATION TO CONFIRM THIS METHOD IS CALLED
        sendBackgroundDebugNotification("📱 AppDelegate Foreground", body: "applicationWillEnterForeground was called")
        
        // REMOVED: checkPendingBackgroundTasks() - now handled by ReturnsApp
    }
    
    // MARK: - Background Task Scheduling
    
    private func scheduleAppRefresh() {
        let identifier = "com.jstick.Returns.refresh"
        
        // Cancel any existing requests first
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        // Use realistic timing - iOS rarely grants requests shorter than 15 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh task scheduled for: \(request.earliestBeginDate ?? Date())")
            
            // SEND IMMEDIATE NOTIFICATION TO CONFIRM SCHEDULING
            sendBackgroundDebugNotification("📅 Background Task Scheduled",
                                           body: "Next execution: \(DateFormatter.timeFormatter.string(from: request.earliestBeginDate ?? Date()))")
            
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
            sendBackgroundDebugNotification("❌ Background Task Failed",
                                           body: "Error: \(error.localizedDescription)")
            
            // Log specific error types for debugging
            if let bgError = error as? BGTaskScheduler.Error {
                switch bgError.code {
                case .unavailable:
                    print("💡 Background tasks unavailable - check device settings")
                case .tooManyPendingTaskRequests:
                    print("💡 Too many pending task requests - app may be over-scheduling")
                case .notPermitted:
                    print("💡 Background refresh not permitted by user")
                default:
                    print("💡 Unknown BGTaskScheduler error: \(bgError)")
                }
            }
        }
    }
    
    private func checkPendingBackgroundTasks() {
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            DispatchQueue.main.async {
                print("📋 Pending background tasks: \(requests.count)")
                for request in requests {
                    print("  - \(request.identifier): \(request.earliestBeginDate ?? Date())")
                }
            }
        }
    }
    
    // MARK: - Background Task Execution
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 EXECUTING BACKGROUND TASK: \(Date())")
        
        // SEND IMMEDIATE NOTIFICATION THAT BACKGROUND TASK STARTED
        sendBackgroundDebugNotification("🚀 Background Task Started",
                                       body: "iOS granted background execution time")
        
        // IMPORTANT: Schedule the next background refresh FIRST
        scheduleAppRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            print("⏰ Background task expired - time limit reached")
            self.sendBackgroundDebugNotification("⏰ Background Task Expired",
                                               body: "iOS time limit reached")
            task.setTaskCompleted(success: false)
        }
        
        // Create a work item for our background task
        let workItem = DispatchWorkItem {
            self.performBackgroundUpdates { success in
                print("📊 Background updates completed: \(success ? "✅ SUCCESS" : "❌ FAILED")")
                
                // SEND COMPLETION NOTIFICATION
                self.sendBackgroundDebugNotification("📊 Background Task Complete",
                                                   body: success ? "Updates successful" : "Updates failed")
                
                task.setTaskCompleted(success: success)
            }
        }
        
        // Execute the background work
        DispatchQueue.global(qos: .background).async(execute: workItem)
        
        // Safety timeout
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 25) {
            if !workItem.isCancelled {
                print("⚠️ Background task taking too long, cancelling...")
                workItem.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Background Work Implementation
    
    private func performBackgroundUpdates(completion: @escaping (Bool) -> Void) {
        print("🔍 Starting comprehensive background updates...")
        
        let group = DispatchGroup()
        var trackingSuccess = false
        var emailSuccess = false
        
        // Task 1: Update package tracking
        group.enter()
        performBackgroundTrackingUpdates { success in
            trackingSuccess = success
            group.leave()
        }
        
        // Task 2: Scan emails for new returns (if Gmail is connected)
        if GmailAuthManager.shared.isAuthenticated {
            group.enter()
            performBackgroundEmailScan { success in
                emailSuccess = success
                group.leave()
            }
        } else {
            emailSuccess = true // Consider it successful if not needed
        }
        
        // Wait for both tasks to complete
        group.notify(queue: .main) {
            let overallSuccess = trackingSuccess && emailSuccess
            print("📊 Background update summary:")
            print("  📦 Tracking updates: \(trackingSuccess ? "✅" : "❌")")
            print("  📧 Email scanning: \(emailSuccess ? "✅" : "❌")")
            print("  🎯 Overall result: \(overallSuccess ? "✅ SUCCESS" : "❌ FAILED")")
            
            completion(overallSuccess)
        }
    }
    
    // MARK: - Background Tracking Updates
    
    private func performBackgroundTrackingUpdates(completion: @escaping (Bool) -> Void) {
        print("📦 Starting background tracking updates...")
        
        // Load current returns from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "ReturnItems"),
              let returnItems = try? JSONDecoder().decode([ReturnItem].self, from: data) else {
            print("❌ No return items found or failed to decode")
            completion(false)
            return
        }
        
        // Filter items that need tracking updates
        let itemsNeedingUpdate = returnItems.filter { item in
            guard item.refundStatus != .completed && item.refundStatus != .processed,
                  let trackingNumber = item.trackingNumber, !trackingNumber.isEmpty else {
                return false
            }
            
            // Update if never tracked or last tracked more than 4 hours ago
            if let lastTracked = item.lastTracked {
                return lastTracked < Date().addingTimeInterval(-4 * 60 * 60) // 4 hours
            }
            return true
        }
        
        guard !itemsNeedingUpdate.isEmpty else {
            print("📦 No items need tracking updates")
            completion(true)
            return
        }
        
        print("📦 Found \(itemsNeedingUpdate.count) items needing tracking updates")
        
        let group = DispatchGroup()
        var updatedItems: [ReturnItem] = returnItems
        var hasChanges = false
        
        for item in itemsNeedingUpdate {
            guard let trackingNumber = item.trackingNumber else { continue }
            
            group.enter()
            TrackingService.shared.fetchTrackingInfo(trackingNumber: trackingNumber) { result in
                defer { group.leave() }
                
                switch result {
                case .success(let newTrackingInfo):
                    // Find the item in our updated array
                    if let index = updatedItems.firstIndex(where: { $0.id == item.id }) {
                        let oldStatus = updatedItems[index].trackingInfo?.status
                        
                        // Update the tracking info
                        updatedItems[index].trackingInfo = newTrackingInfo
                        updatedItems[index].lastTracked = Date()
                        
                        // Update refund status if delivered
                        if newTrackingInfo.status == .delivered && updatedItems[index].refundStatus == .shipped {
                            updatedItems[index].refundStatus = .received
                        }
                        
                        hasChanges = true
                        
                        // Send notification if status changed
                        if let oldStatus = oldStatus, oldStatus != newTrackingInfo.status {
                            print("📦 Status changed for \(item.productName): \(oldStatus.rawValue) → \(newTrackingInfo.status.rawValue)")
                            self.sendTrackingNotification(
                                item: updatedItems[index],
                                newStatus: newTrackingInfo.status,
                                oldStatus: oldStatus
                            )
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update tracking for \(trackingNumber): \(error)")
                }
            }
        }
        
        group.notify(queue: .main) {
            if hasChanges {
                // Save updated items back to UserDefaults
                if let data = try? JSONEncoder().encode(updatedItems) {
                    UserDefaults.standard.set(data, forKey: "ReturnItems")
                    print("📦 Saved \(updatedItems.count) updated return items")
                }
            }
            
            completion(true)
        }
    }
    
    // MARK: - Background Email Scanning
    
    private func performBackgroundEmailScan(completion: @escaping (Bool) -> Void) {
        print("📧 Starting background email scan...")
        
        // Check Gmail authentication
        guard GmailAuthManager.shared.isAuthenticated else {
            print("❌ Gmail not authenticated")
            completion(false)
            return
        }
        
        // Get last scan timestamp
        let lastScanKey = "lastEmailScanTimestamp"
        let lastScan = UserDefaults.standard.object(forKey: lastScanKey) as? Date ?? Date.distantPast
        
        // Only scan if it's been more than 1 hour since last scan
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        guard lastScan < oneHourAgo else {
            print("📧 Email scan not needed - last scan was recent")
            completion(true)
            return
        }
        
        EmailScannerService.shared.scanEmailsForReturns()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        print("✅ Background email scan completed successfully")
                        // Update last scan timestamp
                        UserDefaults.standard.set(Date(), forKey: lastScanKey)
                        completion(true)
                    case .failure(let error):
                        print("❌ Background email scan failed: \(error)")
                        completion(false)
                    }
                },
                receiveValue: { potentialReturns in
                    print("📧 Found \(potentialReturns.count) potential returns in background scan")
                    
                    // Filter out already processed/hidden emails
                    let newReturns = potentialReturns.filter { potentialReturn in
                        !EmailFilterManager.shared.isEmailHidden(potentialReturn.emailId) &&
                        !UserDefaults.standard.bool(forKey: "added_\(potentialReturn.emailId)")
                    }
                    
                    if !newReturns.isEmpty {
                        print("📧 Found \(newReturns.count) new potential returns")
                        self.sendEmailScanNotification(count: newReturns.count)
                    } else {
                        print("📧 No new returns found (all already processed)")
                    }
                }
            )
            .store(in: &self.cancellables)
    }
    
    // MARK: - Notification Helpers
    
    private func sendTrackingNotification(item: ReturnItem, newStatus: TrackingStatus, oldStatus: TrackingStatus) {
        let content = UNMutableNotificationContent()
        content.title = "📦 Package Update"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Customize message based on status
        switch newStatus {
        case .inTransit:
            content.body = "Your return to \(item.retailer) is now in transit"
        case .outForDelivery:
            content.body = "🚚 Your return to \(item.retailer) is out for delivery"
        case .delivered:
            content.body = "✅ Your return to \(item.retailer) has been delivered!"
        case .exception:
            content.body = "⚠️ Issue with your return to \(item.retailer)"
        case .pending:
            content.body = "⏳ Your return to \(item.retailer) is being processed"
        case .unknown:
            return // Don't notify for unknown status
        }
        
        content.subtitle = item.productName
        
        // Add user info for handling notification taps
        content.userInfo = [
            "type": "tracking_update",
            "itemID": item.id.uuidString,
            "newStatus": newStatus.rawValue,
            "retailer": item.retailer
        ]
        
        // Create immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "bg_tracking_\(item.id.uuidString)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send tracking notification: \(error)")
            } else {
                print("📬 Sent tracking notification: \(item.retailer) - \(newStatus.rawValue)")
            }
        }
    }
    
    private func sendEmailScanNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "📧 New Returns Found"
        content.body = "Found \(count) potential return\(count == 1 ? "" : "s") in your email. Tap to review."
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        content.userInfo = [
            "type": "email_scan_results",
            "count": count
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "bg_email_scan_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send email scan notification: \(error)")
            } else {
                print("📬 Sent email scan notification: \(count) new returns")
            }
        }
    }
    
    // MARK: - Debug Notification Helper
    
    private func sendBackgroundDebugNotification(_ title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        content.userInfo = [
            "type": "background_debug",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bg_debug_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send debug notification: \(error)")
            } else {
                print("📬 Sent debug notification: \(title)")
            }
        }
    }
    
    // MARK: - Test Notification Helper
    
    private func sendTestNotification(_ title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Add timestamp to make each notification unique
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        content.subtitle = "Background Test - \(timestamp)"
        
        content.userInfo = [
            "type": "background_test",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bg_test_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send test notification: \(error)")
            } else {
                print("📬 Sent test notification: \(title)")
            }
        }
    }
    
    // MARK: - Debug Methods (Development Only)
    
    #if DEBUG
    func testBackgroundEmailScan() {
        print("🧪 TESTING BACKGROUND EMAIL SCAN...")
        performBackgroundEmailScan { success in
            print("🧪 Test email scan result: \(success ? "✅ SUCCESS" : "❌ FAILED")")
        }
    }
    
    func testBackgroundTrackingUpdates() {
        print("🧪 TESTING BACKGROUND TRACKING UPDATES...")
        performBackgroundTrackingUpdates { success in
            print("🧪 Test tracking updates result: \(success ? "✅ SUCCESS" : "❌ FAILED")")
        }
    }
    
    func testFullBackgroundUpdates() {
        print("🧪 TESTING FULL BACKGROUND UPDATES...")
        performBackgroundUpdates { success in
            print("🧪 Test full updates result: \(success ? "✅ SUCCESS" : "❌ FAILED")")
        }
    }
    
    func forceBackgroundTaskExecution() {
        print("🔄 Forcing background task execution...")
        scheduleAppRefresh()
        
        // Send notification that task was scheduled
        sendTestNotification("📅 Background Task Scheduled", body: "Task will run when iOS decides to execute it")
    }
    
    func cancelAllBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("🗑️ Cancelled all background tasks")
    }
    
    func getBackgroundTaskStatus() -> String {
        let status = UIApplication.shared.backgroundRefreshStatus
        switch status {
        case .available: return "Available"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
    #endif
    
    // MARK: - URL Handling for OAuth
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("🔗 App opened with URL: \(url.absoluteString)")
        return true
    }
    
    // MARK: - Notification Delegate Methods
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
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
            case "background_test":
                handleBackgroundTestNotificationTap(userInfo: userInfo)
            case "email_scan_results":
                handleEmailScanNotificationTap(userInfo: userInfo)
            case "background_debug":
                handleBackgroundDebugNotificationTap(userInfo: userInfo)
            default:
                print("📱 Unknown notification type: \(notificationType)")
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Notification Tap Handlers
    
    private func handleTrackingNotificationTap(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        guard let itemIDString = userInfo["itemID"] as? String,
              let itemID = UUID(uuidString: itemIDString) else { return }
        
        switch actionIdentifier {
        case "MARK_RECEIVED":
            print("📱 Mark as received tapped for item: \(itemID)")
        case "VIEW_DETAILS", UNNotificationDefaultActionIdentifier:
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
        NotificationCenter.default.post(name: .refreshReturnsList, object: nil)
    }
    
    private func handleEmailScanNotificationTap(userInfo: [AnyHashable: Any]) {
        print("📱 Email scan notification tapped")
        if let count = userInfo["count"] as? Int {
            print("📱 Found \(count) new returns - opening Gmail integration")
        }
        NotificationCenter.default.post(name: .openGmailIntegration, object: nil)
    }
    
    private func handleBackgroundTestNotificationTap(userInfo: [AnyHashable: Any]) {
        print("📱 Background test notification tapped")
        if let timestamp = userInfo["timestamp"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            print("📱 Test was executed at: \(date)")
        }
    }
    
    private func handleBackgroundDebugNotificationTap(userInfo: [AnyHashable: Any]) {
        print("📱 Background debug notification tapped")
        if let timestamp = userInfo["timestamp"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            print("📱 Debug notification sent at: \(date)")
        }
    }
}

// MARK: - Notification Navigation Constants

extension Notification.Name {
    static let navigateToReturnDetail = Notification.Name("navigateToReturnDetail")
    static let refreshReturnsList = Notification.Name("refreshReturnsList")
    static let openGmailIntegration = Notification.Name("openGmailIntegration")
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
