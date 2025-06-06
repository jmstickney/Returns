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
        
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Setup notification categories
        NotificationManager.shared.setupNotificationCategories()
        
        // Check background refresh status
        checkBackgroundRefreshStatus()
        
        // Register background tasks
        registerBackgroundTasks()
        
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
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        let identifier = "com.jstick.Returns.refresh"
        
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            print("🔄 BACKGROUND TASK TRIGGERED: \(Date())")
            print("📋 Task identifier: \(task.identifier)")
            
            // Safe casting with proper error handling
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                print("❌ Wrong task type received: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            
            self.handleAppRefresh(task: appRefreshTask)
        }
        
        print("🔧 Background task registration (\(identifier)): \(registered ? "✅ SUCCESS" : "❌ FAILED")")
        
        if !registered {
            print("💡 Check Info.plist for BGTaskSchedulerPermittedIdentifiers")
        }
    }
    
    // MARK: - App Lifecycle Events
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 App entered background - scheduling refresh task")
        scheduleAppRefresh()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App entering foreground")
        checkPendingBackgroundTasks()
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
            print("✅ Background refresh task scheduled")
            print("🕐 Earliest begin date: \(request.earliestBeginDate ?? Date())")
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
            print("📝 Error details: \(error.localizedDescription)")
            
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
        
        // IMPORTANT: Schedule the next background refresh FIRST
        // This ensures continuous background refresh capability
        scheduleAppRefresh()
        
        // Set expiration handler - iOS gives limited time for background execution
        task.expirationHandler = {
            print("⏰ Background task expired - time limit reached")
            task.setTaskCompleted(success: false)
        }
        
        // Create a work item for our background task
        let workItem = DispatchWorkItem {
            self.performBackgroundTrackingUpdate { success in
                print("📊 Background tracking update completed: \(success ? "✅ SUCCESS" : "❌ FAILED")")
                task.setTaskCompleted(success: success)
            }
        }
        
        // Execute the background work
        DispatchQueue.global(qos: .background).async(execute: workItem)
        
        // Safety timeout - iOS typically gives 30 seconds max for background tasks
        // We'll use 25 seconds to be safe
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 25) {
            if !workItem.isCancelled {
                print("⚠️ Background task taking too long, cancelling...")
                workItem.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Background Work Implementation (SIMPLIFIED FOR TESTING)
    
    private func performBackgroundTrackingUpdate(completion: @escaping (Bool) -> Void) {
        print("🔍 Starting SIMPLE background email scan test...")
        
        // Send immediate notification that background task started
        sendTestNotification("🚀 Background Task Started", body: "Testing background email scan...")
        
        // Check Gmail authentication
        guard GmailAuthManager.shared.isAuthenticated else {
            print("❌ Gmail not authenticated")
            sendTestNotification("❌ Gmail Not Connected", body: "Connect Gmail to test email scanning")
            completion(false)
            return
        }
        
        // Perform simple background email scan
        DispatchQueue.global(qos: .background).async {
            print("🔄 Performing background email scan...")
            
            // Simple email scan test using your existing EmailScannerService
            EmailScannerService.shared.scanEmailsForReturns()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completionResult in
                        switch completionResult {
                        case .finished:
                            print("✅ Email scan completed successfully")
                        case .failure(let error):
                            print("❌ Email scan failed: \(error)")
                            self.sendTestNotification("❌ Email Scan Failed", body: "Error: \(error.localizedDescription)")
                            completion(false)
                        }
                    },
                    receiveValue: { potentialReturns in
                        print("📧 Found \(potentialReturns.count) potential returns")
                        
                        // Send success notification with results
                        let title = "✅ Email Scan Complete"
                        let body = "Found \(potentialReturns.count) potential returns in background"
                        self.sendTestNotification(title, body: body)
                        
                        // Log some details for debugging
                        for (index, return_item) in potentialReturns.prefix(3).enumerated() {
                            print("📦 Return \(index + 1): \(return_item.retailer) - $\(return_item.refundAmount)")
                        }
                        
                        completion(true)
                    }
                )
                .store(in: &self.cancellables)
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
        performBackgroundTrackingUpdate { success in
            print("🧪 Test email scan result: \(success ? "✅ SUCCESS" : "❌ FAILED")")
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
    
    private func handleBackgroundTestNotificationTap(userInfo: [AnyHashable: Any]) {
        print("📱 Background test notification tapped")
        if let timestamp = userInfo["timestamp"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            print("📱 Test was executed at: \(date)")
        }
    }
}

// MARK: - Notification Navigation Constants

extension Notification.Name {
    static let navigateToReturnDetail = Notification.Name("navigateToReturnDetail")
    static let refreshReturnsList = Notification.Name("refreshReturnsList")
}
