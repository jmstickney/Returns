//
//  ReturnItem.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//


import Foundation
import SwiftUI

struct ReturnItem: Identifiable, Codable {
    var id = UUID()
    var productName: String
    var retailer: String
    //var returnDate: Date
    var trackingNumber: String?
    var refundAmount: Double
    var refundStatus: RefundStatus
    var notes: String?
    
    // Image identifiers (filenames)
    var productImageID: UUID?
    var returnLabelImageID: UUID?
    var packagingImageID: UUID?
    
    // Reminders
    var reminders: [ReturnReminder] = []
    
    // Tracking information
    var trackingInfo: TrackingInfo?
    var lastTracked: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, productName, retailer, trackingNumber, refundAmount, refundStatus, notes
        case productImageID, returnLabelImageID, packagingImageID, reminders
        case trackingInfo, lastTracked
    }
}

enum RefundStatus: String, CaseIterable, Identifiable, Codable {
    case pending = "Pending"
    case shipped = "Return Shipped"
    case received = "Return Received"
    case processed = "Refund Processed"
    case completed = "Completed"
    
    var id: String { self.rawValue }
}

enum ImageType: String, CaseIterable {
    case product = "Product"
    case returnLabel = "Return Label"
    case packaging = "Packaging"
}
