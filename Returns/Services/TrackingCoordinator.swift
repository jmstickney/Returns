//
//  TrackingCoordinator.swift
//  Returns
//
//  Created by Jonathan Stickney on 4/16/25.
//

import Foundation
import SwiftUI

class TrackingCoordinator: ObservableObject {
    private let viewModel: ReturnsViewModel
    private let itemID: UUID
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var trackingNumber: String?
    @Published var trackingInfo: TrackingInfo?
    @Published var lastTracked: Date?
    
    init(viewModel: ReturnsViewModel, itemID: UUID) {
        self.viewModel = viewModel
        self.itemID = itemID
        
        // Initialize with current data
        if let item = viewModel.returnItems.first(where: { $0.id == itemID }) {
            self.trackingInfo = item.trackingInfo
            self.lastTracked = item.lastTracked
            self.trackingNumber = item.trackingNumber
        }
    }
    
    func refreshTracking() {
        isLoading = true
        errorMessage = nil
        
        // Store these locally to prevent capturing self in closure
        let currentItemID = self.itemID
        let trackingNumber = self.trackingNumber ?? ""
        
        // Use the tracking service directly instead of the view model
        if !trackingNumber.isEmpty {
            TrackingService.shared.fetchTrackingInfo(trackingNumber: trackingNumber) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let info):
                        self.trackingInfo = info
                        self.lastTracked = Date()
                        
                        // Update the view model separately
                        // Do this after a slight delay to prevent navigation issues
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let index = self.viewModel.returnItems.firstIndex(where: { $0.id == currentItemID }) {
                                self.viewModel.returnItems[index].trackingInfo = info
                                self.viewModel.returnItems[index].lastTracked = Date()
                                
                                // If delivered and status is still "shipped", update to "received"
                                if info.status == .delivered && self.viewModel.returnItems[index].refundStatus == .shipped {
                                    self.viewModel.returnItems[index].refundStatus = .received
                                }
                            }
                        }
                        
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        } else {
            self.isLoading = false
            self.errorMessage = "No tracking number available"
            self.showError = true
        }
    }
    
    func shouldAutoUpdate() -> Bool {
        return viewModel.shouldAutoUpdateTracking(for: itemID)
    }
}
