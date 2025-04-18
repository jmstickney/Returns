//
//  ReturnReminder.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import Foundation
import UserNotifications

struct ReturnReminder: Identifiable, Codable {
    var id = UUID()
    var returnItemID: UUID
    var reminderDate: Date
    var message: String
    var isActive: Bool = true
    var notificationID: String
    
    init(returnItemID: UUID, reminderDate: Date, message: String) {
        self.returnItemID = returnItemID
        self.reminderDate = reminderDate
        self.message = message
        self.notificationID = UUID().uuidString
    }
}

class ReminderManager {
    static let shared = ReminderManager()
    
    private init() {
        requestNotificationPermission()
    }
    
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
    
    func scheduleReminder(_ reminder: ReturnReminder, productName: String) -> ReturnReminder {
        let content = UNMutableNotificationContent()
        content.title = "Return Reminder"
        content.body = "\(productName): \(reminder.message)"
        content.sound = .default
        
        // Create date components from the reminder date
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.reminderDate
        )
        
        // Create the trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: reminder.notificationID,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
        
        return reminder
    }
    
    func cancelReminder(_ reminder: ReturnReminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.notificationID]
        )
    }
}