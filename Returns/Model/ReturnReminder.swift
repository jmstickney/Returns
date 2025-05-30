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

// Note: ReminderManager functionality has been moved to NotificationManager
// This maintains the ReturnReminder struct but removes the separate manager class
// to consolidate all notification handling in one place
