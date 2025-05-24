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
        self.showOnboarding = true //!UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.hasRequestedNotificationPermission = UserDefaults.standard.bool(forKey: "hasRequestedNotificationPermission")
    }
    
    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
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
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error requesting notification authorization: \(error.localizedDescription)")
                    }
                    
                    if granted {
                        print("Notification authorization granted.")
                    } else {
                        print("Notification authorization denied.")
                    }
                    
                    self.markNotificationPermissionRequested()
                    completion(granted)
                }
            }
        } else {
            // If already requested, just check the current status
            checkNotificationStatus { granted in
                completion(granted)
            }
        }
    }
    
    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized ||
                              settings.authorizationStatus == .provisional ||
                              settings.authorizationStatus == .ephemeral
                completion(granted)
            }
        }
    }
}
