//
//  NotificationManager.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/21/25.
//

import Foundation
import UserNotifications
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        // Remove automatic permission request - only request when user explicitly opts in
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermissions(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permissions granted")
                    // Request background app refresh permission
                    UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
                } else {
                    print("❌ Notification permissions denied")
                }
                
                if let error = error {
                    print("Error requesting notification permissions: \(error)")
                }
                
                completion(granted)
            }
        }
    }
    
    func checkNotificationPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized ||
                              settings.authorizationStatus == .provisional ||
                              settings.authorizationStatus == .ephemeral
                completion(granted)
            }
        }
    }
    
    // MARK: - Tracking Status Notifications
    
    func scheduleTrackingStatusNotification(for item: ReturnItem, newStatus: TrackingStatus, oldStatus: TrackingStatus?) {
        let content = UNMutableNotificationContent()
        content.title = "Return Status Update"
        content.sound = .default
        content.badge = 1
        
        // Customize message based on status
        switch newStatus {
        case .inTransit:
            content.body = "📦 Your return to \(item.retailer) is now in transit"
            content.subtitle = item.productName
        case .outForDelivery:
            content.body = "🚚 Your return to \(item.retailer) is out for delivery"
            content.subtitle = item.productName
        case .delivered:
            content.body = "✅ Your return to \(item.retailer) has been delivered!"
            content.subtitle = "\(item.productName) - Check for refund processing"
        case .exception:
            content.body = "⚠️ Issue with your return to \(item.retailer)"
            content.subtitle = "\(item.productName) - Check tracking details"
        case .pending:
            content.body = "⏳ Your return to \(item.retailer) is being processed"
            content.subtitle = item.productName
        case .unknown:
            return // Don't notify for unknown status
        }
        
        // Add user info for handling notification taps
        content.userInfo = [
            "type": "tracking_update",
            "itemID": item.id.uuidString,
            "newStatus": newStatus.rawValue,
            "retailer": item.retailer
        ]
        
        // Create immediate trigger (since this is called when status changes)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "tracking_\(item.id.uuidString)_\(newStatus.rawValue)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling tracking notification: \(error)")
            } else {
                print("✅ Scheduled tracking notification for \(item.retailer) - \(newStatus.rawValue)")
            }
        }
    }
    
    // MARK: - Reminder Notifications (existing functionality)
    
    func scheduleReminder(_ reminder: ReturnReminder, productName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Return Reminder"
        content.body = "\(productName): \(reminder.message)"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "reminder",
            "reminderID": reminder.id.uuidString,
            "itemID": reminder.returnItemID.uuidString
        ]
        
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.reminderDate
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: reminder.notificationID,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling reminder: \(error)")
            }
        }
    }
    
    func cancelReminder(_ reminder: ReturnReminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.notificationID]
        )
    }
    
    // MARK: - Automatic Return Deadline Notifications
    
    func scheduleReturnDeadlineNotifications(for item: ReturnItem) {
        // Most retailers have 30-day return windows, schedule reminders accordingly
        let calendar = Calendar.current
        
        // 7 days warning
        if let reminderDate = calendar.date(byAdding: .day, value: 7, to: Date()) {
            scheduleReturnDeadlineNotification(
                for: item,
                date: reminderDate,
                daysLeft: 23, // Assuming 30-day window
                urgency: .normal
            )
        }
        
        // 3 days warning
        if let reminderDate = calendar.date(byAdding: .day, value: 27, to: Date()) {
            scheduleReturnDeadlineNotification(
                for: item,
                date: reminderDate,
                daysLeft: 3,
                urgency: .urgent
            )
        }
        
        // Final day warning
        if let reminderDate = calendar.date(byAdding: .day, value: 29, to: Date()) {
            scheduleReturnDeadlineNotification(
                for: item,
                date: reminderDate,
                daysLeft: 1,
                urgency: .critical
            )
        }
    }
    
    private func scheduleReturnDeadlineNotification(for item: ReturnItem, date: Date, daysLeft: Int, urgency: NotificationUrgency) {
        let content = UNMutableNotificationContent()
        content.sound = urgency == .critical ? .defaultCritical : .default
        content.badge = 1
        
        switch urgency {
        case .normal:
            content.title = "Return Deadline Reminder"
            content.body = "⏰ \(daysLeft) days left to return \(item.productName) to \(item.retailer)"
        case .urgent:
            content.title = "Return Deadline Soon!"
            content.body = "⚠️ Only \(daysLeft) days left to return \(item.productName) to \(item.retailer)"
        case .critical:
            content.title = "Final Return Warning!"
            content.body = "🚨 Last day to return \(item.productName) to \(item.retailer)!"
        }
        
        content.userInfo = [
            "type": "deadline_warning",
            "itemID": item.id.uuidString,
            "daysLeft": daysLeft,
            "urgency": urgency.rawValue
        ]
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "deadline_\(item.id.uuidString)_\(daysLeft)days",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling deadline notification: \(error)")
            }
        }
    }
    
    // MARK: - Background Refresh Notifications
    
    func scheduleBackgroundRefreshNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Return Updates Available"
        content.body = "New tracking updates found for your returns"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "background_refresh",
            "action": "refresh_tracking"
        ]
        
        // Schedule for immediate delivery (called from background refresh)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "background_refresh_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling background refresh notification: \(error)")
            }
        }
    }
    
    // MARK: - Notification Categories & Actions
    
    func setupNotificationCategories() {
        // View Details action
        let viewDetailsAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )
        
        // Mark as Received action (for delivered items)
        let markReceivedAction = UNNotificationAction(
            identifier: "MARK_RECEIVED",
            title: "Mark as Received",
            options: []
        )
        
        // Tracking Update Category
        let trackingCategory = UNNotificationCategory(
            identifier: "TRACKING_UPDATE",
            actions: [viewDetailsAction, markReceivedAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Deadline Warning Category
        let deadlineCategory = UNNotificationCategory(
            identifier: "DEADLINE_WARNING",
            actions: [viewDetailsAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([trackingCategory, deadlineCategory])
    }
}

enum NotificationUrgency: String {
    case normal = "normal"
    case urgent = "urgent"
    case critical = "critical"
}
