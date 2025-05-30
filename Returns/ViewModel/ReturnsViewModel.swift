//  ReturnsViewModel.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import Foundation
import SwiftUI

class ReturnsViewModel: ObservableObject {
    @Published var returnItems: [ReturnItem] = [] {
        didSet {
            saveReturns()
        }
    }
    
    private let imageManager = ImageManager.shared
    //private let reminderManager = ReminderManager.shared
    
    init() {
        loadReturns()
    }
    
    // MARK: - Basic CRUD Operations
    
    func addReturn(item: ReturnItem) {
        returnItems.append(item)
    }
    
    func updateStatus(for item: ReturnItem, newStatus: RefundStatus) {
        updateReturnItem(withID: item.id) { returnItem in
            returnItem.refundStatus = newStatus
        }
    }
    
    func updateItem(_ updatedItem: ReturnItem) {
        if let index = returnItems.firstIndex(where: { $0.id == updatedItem.id }) {
            // Preserve images and reminders from the existing item
            let existing = returnItems[index]
            var newItem = updatedItem
            newItem.productImageID = existing.productImageID
            newItem.returnLabelImageID = existing.returnLabelImageID
            newItem.packagingImageID = existing.packagingImageID
            newItem.reminders = existing.reminders
            newItem.trackingInfo = existing.trackingInfo
            newItem.lastTracked = existing.lastTracked
            
            // If tracking number changed, reset tracking info
            if existing.trackingNumber != newItem.trackingNumber {
                newItem.trackingInfo = nil
                newItem.lastTracked = nil
            }
            
            returnItems[index] = newItem
        }
    }
    
    func deleteReturn(at offsets: IndexSet) {
        for idx in offsets {
            let item = returnItems[idx]
            // delete images & cancel reminders
            if let pid = item.productImageID { imageManager.deleteImage(withID: pid) }
            if let rid = item.returnLabelImageID { imageManager.deleteImage(withID: rid) }
            if let pkg = item.packagingImageID { imageManager.deleteImage(withID: pkg) }
            
            // Use NotificationManager instead of ReminderManager
            item.reminders.forEach { NotificationManager.shared.cancelReminder($0) }
        }
        returnItems.remove(atOffsets: offsets)
    }
    
    // MARK: - In-Place Mutation Helper
    /// Mutates only the specified ReturnItem within returnItems, preserving the array instance
    func updateReturnItem(withID id: UUID, transform: (inout ReturnItem) -> Void) {
        guard let index = returnItems.firstIndex(where: { $0.id == id }) else { return }
        transform(&returnItems[index])
    }
    
    // MARK: - Tracking Methods
    
    func updateTracking(for itemID: UUID, completion: @escaping (Result<TrackingInfo, Error>) -> Void) {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }),
              let trackingNumber = returnItems[idx].trackingNumber,
              !trackingNumber.isEmpty else {
            completion(.failure(NSError(domain: "ReturnsTracker", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "No tracking number available"])))
            return
        }
        
        TrackingService.shared.fetchTrackingInfo(trackingNumber: trackingNumber) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    self.updateReturnItem(withID: itemID) { item in
                        item.trackingInfo = info
                        item.lastTracked = Date()
                        if info.status == .delivered && item.refundStatus == .shipped {
                            item.refundStatus = .received
                        }
                    }
                    completion(.success(info))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func shouldAutoUpdateTracking(for itemID: UUID) -> Bool {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }) else { return false }
        let item = returnItems[idx]
        guard item.refundStatus != .completed && item.refundStatus != .processed,
              let tracking = item.trackingNumber, !tracking.isEmpty else { return false }
        if let last = item.lastTracked {
            return last < Date().addingTimeInterval(-4*60*60)
        }
        return true
    }
    
    // MARK: - Image Handling
    
    func setImage(_ image: UIImage?, for type: ImageType, itemID: UUID) {
        updateReturnItem(withID: itemID) { item in
            switch type {
            case .product:
                if let img = image { item.productImageID = imageManager.saveImage(img, withID: item.productImageID) }
                else if let pid = item.productImageID { imageManager.deleteImage(withID: pid); item.productImageID = nil }
            case .returnLabel:
                if let img = image { item.returnLabelImageID = imageManager.saveImage(img, withID: item.returnLabelImageID) }
                else if let rid = item.returnLabelImageID { imageManager.deleteImage(withID: rid); item.returnLabelImageID = nil }
            case .packaging:
                if let img = image { item.packagingImageID = imageManager.saveImage(img, withID: item.packagingImageID) }
                else if let pkg = item.packagingImageID { imageManager.deleteImage(withID: pkg); item.packagingImageID = nil }
            }
        }
    }
    
    func getImage(for type: ImageType, itemID: UUID) -> UIImage? {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }) else { return nil }
        switch type {
        case .product:     return imageManager.loadImage(withID: returnItems[idx].productImageID)
        case .returnLabel: return imageManager.loadImage(withID: returnItems[idx].returnLabelImageID)
        case .packaging:   return imageManager.loadImage(withID: returnItems[idx].packagingImageID)
        }
    }
    
    // MARK: - Reminder Methods
    
    func addReminder(
        for itemID: UUID,
        date: Date,
        message: String
    ) -> Bool {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }) else { return false }
        var reminder = ReturnReminder(returnItemID: itemID, reminderDate: date, message: message)
        
        // Use NotificationManager instead of ReminderManager
        NotificationManager.shared.scheduleReminder(reminder, productName: returnItems[idx].productName)
        
        returnItems[idx].reminders.append(reminder)
        return true
    }
    
    func deleteReminder(itemID: UUID, reminderID: UUID) {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }),
              let ridx = returnItems[idx].reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        
        // Use NotificationManager instead of ReminderManager
        NotificationManager.shared.cancelReminder(returnItems[idx].reminders[ridx])
        
        returnItems[idx].reminders.remove(at: ridx)
    }
    
    func getRemindersForItem(id: UUID) -> [ReturnReminder] {
        return returnItems.first(where: { $0.id == id })?.reminders ?? []
    }
    
    // MARK: - Persistence
    
    private func saveReturns() {
        if let data = try? JSONEncoder().encode(returnItems) {
            UserDefaults.standard.set(data, forKey: "ReturnItems")
        }
    }
    
    private func loadReturns() {
        if let data = UserDefaults.standard.data(forKey: "ReturnItems"),
           let decoded = try? JSONDecoder().decode([ReturnItem].self, from: data) {
            returnItems = decoded
        } else {
            returnItems = []
        }
    }
}
//
//  Add this extension to your existing ReturnsViewModel.swift file
//

extension ReturnsViewModel {
    
    // MARK: - Enhanced Tracking with Notifications
    
    func updateTrackingWithNotifications(for itemID: UUID, completion: @escaping (Result<TrackingInfo, Error>) -> Void) {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }),
              let trackingNumber = returnItems[idx].trackingNumber,
              !trackingNumber.isEmpty else {
            completion(.failure(NSError(domain: "ReturnsTracker", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "No tracking number available"])))
            return
        }
        
        let previousStatus = returnItems[idx].trackingInfo?.status
        
        TrackingService.shared.fetchTrackingInfo(trackingNumber: trackingNumber) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    self.updateReturnItem(withID: itemID) { item in
                        item.trackingInfo = info
                        item.lastTracked = Date()
                        if info.status == .delivered && item.refundStatus == .shipped {
                            item.refundStatus = .received
                        }
                    }
                    
                    // Send notification if status changed
                    if let previousStatus = previousStatus, previousStatus != info.status {
                        NotificationManager.shared.scheduleTrackingStatusNotification(
                            for: self.returnItems[idx],
                            newStatus: info.status,
                            oldStatus: previousStatus
                        )
                    }
                    
                    completion(.success(info))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Add automatic deadline notifications when creating returns
    func addReturnWithNotifications(item: ReturnItem) {
        returnItems.append(item)
        
        // Schedule automatic deadline notifications
        NotificationManager.shared.scheduleReturnDeadlineNotifications(for: item)
    }
    
    // Updated reminder methods to use NotificationManager
    func addReminderWithNotifications(
        for itemID: UUID,
        date: Date,
        message: String
    ) -> Bool {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }) else { return false }
        var reminder = ReturnReminder(returnItemID: itemID, reminderDate: date, message: message)
        
        // Use NotificationManager instead of ReminderManager
        NotificationManager.shared.scheduleReminder(reminder, productName: returnItems[idx].productName)
        
        returnItems[idx].reminders.append(reminder)
        return true
    }
    
    func deleteReminderWithNotifications(itemID: UUID, reminderID: UUID) {
        guard let idx = returnItems.firstIndex(where: { $0.id == itemID }),
              let ridx = returnItems[idx].reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        
        // Use NotificationManager instead of ReminderManager
        NotificationManager.shared.cancelReminder(returnItems[idx].reminders[ridx])
        
        returnItems[idx].reminders.remove(at: ridx)
    }
}
