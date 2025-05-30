//
//  OnboardingManager.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/21/25.
//

import Foundation
import SwiftUI
import UserNotifications

class OnboardingManager: ObservableObject {
    @Published var showOnboarding: Bool
    @Published var hasRequestedNotificationPermission = false
    
    init() {
        // Check if user has completed onboarding before
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.hasRequestedNotificationPermission = UserDefaults.standard.bool(forKey: "hasRequestedNotificationPermission")
    }
    
    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Notify that onboarding is complete so tutorial can start
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
    
    func resetOnboarding() {
        showOnboarding = true
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    
    func markNotificationPermissionRequested() {
        hasRequestedNotificationPermission = true
        UserDefaults.standard.set(true, forKey: "hasRequestedNotificationPermission")
    }
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        // Only request if we haven't already
        if !hasRequestedNotificationPermission {
            // Use NotificationManager instead of direct UNUserNotificationCenter
            NotificationManager.shared.requestNotificationPermissions { [weak self] granted in
                self?.markNotificationPermissionRequested()
                completion(granted)
            }
        } else {
            // If already requested, just check the current status
            checkNotificationStatus { granted in
                completion(granted)
            }
        }
    }
    
    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        // Use NotificationManager instead of direct UNUserNotificationCenter
        NotificationManager.shared.checkNotificationPermissions { granted in
            completion(granted)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
