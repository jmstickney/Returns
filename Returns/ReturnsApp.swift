//
//  ReturnsApp.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import SwiftUI
import BackgroundTasks
import UserNotifications
import Combine

@main
struct ReturnsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ReturnsViewModel()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var isShowingSplash = true
    @Environment(\.scenePhase) private var scenePhase
    private let refreshTimer = Timer.publish(every: 300, on: .main, in: .common)
                                     .autoconnect()
    
    // Add this for background task handling
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some Scene {
            WindowGroup {
                ZStack {
                    // inject the shared viewModel
                    ReturnsListView(viewModel: viewModel)
                        .opacity(isShowingSplash ? 0 : 1)
                        // splash onAppear
                        .onAppear {
                            // Register background task handler when app appears
                            registerBackgroundTaskHandler()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isShowingSplash = false
                                }
                            }
                        }
                        // 5️⃣ refresh when the app becomes active
                        .onChange(of: scenePhase) { newPhase in
                            print("📱 Scene phase changed to: \(newPhase)")
                            
                            if newPhase == .active {
                                print("📱 App became active - refreshing tracking")
                                refreshAllTracking()
                            } else if newPhase == .background {
                                print("📱 App went to background - should trigger AppDelegate")
                                
                                // Send scene phase notification
                                sendScenePhaseNotification("📱 Scene Phase: Background", body: "App went to background via scene phase")
                                
                                // MANUALLY TRIGGER BACKGROUND TASK SCHEDULING AS BACKUP
                                // Since AppDelegate might not be getting called
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    self.manuallyScheduleBackgroundTask()
                                }
                                
                            } else if newPhase == .inactive {
                                print("📱 App became inactive")
                            }
                        }
                        // 6️⃣ refresh every interval tick
                        .onReceive(refreshTimer) { _ in
                            refreshAllTracking()
                        }
                    
                        .onOpenURL { url in
                                                print("Received URL: \(url)")
                                                // URL handling for OAuth will be automatic through ASWebAuthenticationSession
                                            }

                    if isShowingSplash {
                        LaunchScreen()
                            .transition(.opacity)
                            .zIndex(1)
                    }
                    // Onboarding overlay
                                    if !isShowingSplash && onboardingManager.showOnboarding {
                                        OnboardingView(onboardingManager: onboardingManager)
                                            .transition(.opacity)
                                            .zIndex(2)
                                    }
                }
            }
        }

        /// Loops through items and updates any that need refreshing
        private func refreshAllTracking() {
            for item in viewModel.returnItems {
                guard viewModel.shouldAutoUpdateTracking(for: item.id) else { continue }
                viewModel.updateTracking(for: item.id) { _ in }
            }
        }
    
        // Add background task registration method
        private func registerBackgroundTaskHandler() {
            let identifier = "com.jstick.Returns.refresh"
            
            print("🔧 Registering background task handler from ReturnsApp...")
            
            let registered = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                print("🔄 BACKGROUND TASK TRIGGERED: \(Date())")
                
                // Send notification that background task started
                self.sendScenePhaseNotification("🚀 Background Task Started", body: "iOS granted background execution time")
                
                guard let appRefreshTask = task as? BGAppRefreshTask else {
                    print("❌ Wrong task type received")
                    task.setTaskCompleted(success: false)
                    return
                }
                
                self.handleBackgroundTask(task: appRefreshTask)
            }
            
            if registered {
                print("🔧 ✅ Background task handler registered successfully")
                sendScenePhaseNotification("✅ Background Handler Registered", body: "Ready for background execution")
            } else {
                print("🔧 ❌ Failed to register background task handler")
                sendScenePhaseNotification("❌ Registration Failed", body: "Background task registration failed")
            }
        }
        
        // Add background task execution method
        private func handleBackgroundTask(task: BGAppRefreshTask) {
            print("🔄 EXECUTING BACKGROUND TASK FROM RETURNSAPP")
            
            // Schedule the next background task
            manuallyScheduleBackgroundTask()
            
            // Set expiration handler
            task.expirationHandler = {
                print("⏰ Background task expired")
                self.sendScenePhaseNotification("⏰ Background Task Expired", body: "iOS time limit reached")
                task.setTaskCompleted(success: false)
            }
            
            // Perform the background work
            let workItem = DispatchWorkItem {
                self.performBackgroundWork { success in
                    print("📊 Background work completed: \(success ? "✅ SUCCESS" : "❌ FAILED")")
                    self.sendScenePhaseNotification("📊 Background Work Complete", body: success ? "Updates successful" : "Updates failed")
                    task.setTaskCompleted(success: success)
                }
            }
            
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
        
        // Add background work method
        private func performBackgroundWork(completion: @escaping (Bool) -> Void) {
            print("🔍 Starting background work from ReturnsApp...")
            
            let group = DispatchGroup()
            var emailSuccess = true
            var trackingSuccess = true
            
            // Email scanning (if Gmail connected)
            if GmailAuthManager.shared.isAuthenticated {
                group.enter()
                
                EmailScannerService.shared.scanEmailsForReturns()
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { result in
                            switch result {
                            case .finished:
                                print("✅ Background email scan completed")
                            case .failure(let error):
                                print("❌ Background email scan failed: \(error)")
                                emailSuccess = false
                            }
                            group.leave()
                        },
                        receiveValue: { potentialReturns in
                            print("📧 Found \(potentialReturns.count) potential returns in background")
                            
                            // Filter new returns
                            let newReturns = potentialReturns.filter { potentialReturn in
                                !EmailFilterManager.shared.isEmailHidden(potentialReturn.emailId) &&
                                !UserDefaults.standard.bool(forKey: "added_\(potentialReturn.emailId)")
                            }
                            
                            if !newReturns.isEmpty {
                                print("📧 Found \(newReturns.count) new potential returns")
                                self.sendEmailFoundNotification(count: newReturns.count)
                            }
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // Tracking updates
            group.enter()
            performBackgroundTrackingUpdates { success in
                trackingSuccess = success
                group.leave()
            }
            
            group.notify(queue: .main) {
                let overallSuccess = emailSuccess && trackingSuccess
                completion(overallSuccess)
            }
        }
        
        // Add tracking updates method
        private func performBackgroundTrackingUpdates(completion: @escaping (Bool) -> Void) {
            // Load returns from UserDefaults
            guard let data = UserDefaults.standard.data(forKey: "ReturnItems"),
                  let returnItems = try? JSONDecoder().decode([ReturnItem].self, from: data) else {
                print("❌ No return items found")
                completion(false)
                return
            }
            
            // Filter items that need updates
            let itemsNeedingUpdate = returnItems.filter { item in
                guard item.refundStatus != .completed && item.refundStatus != .processed,
                      let trackingNumber = item.trackingNumber, !trackingNumber.isEmpty else {
                    return false
                }
                
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
            var hasUpdates = false
            
            for item in itemsNeedingUpdate.prefix(3) { // Limit to 3 items for background
                guard let trackingNumber = item.trackingNumber else { continue }
                
                group.enter()
                TrackingService.shared.fetchTrackingInfo(trackingNumber: trackingNumber) { result in
                    defer { group.leave() }
                    
                    switch result {
                    case .success(let trackingInfo):
                        print("✅ Updated tracking for \(item.retailer): \(trackingInfo.status.rawValue)")
                        hasUpdates = true
                        
                        DispatchQueue.main.async {
                            self.sendTrackingUpdateNotification(item: item, status: trackingInfo.status)
                        }
                        
                    case .failure(let error):
                        print("❌ Failed to update tracking for \(trackingNumber): \(error)")
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion(true)
            }
        }
        
        // Add notification helpers
        private func sendEmailFoundNotification(count: Int) {
            let content = UNMutableNotificationContent()
            content.title = "📧 New Returns Found"
            content.body = "Found \(count) potential returns in your email. Tap to review."
            content.sound = .default
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "bg_email_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { _ in }
        }
        
        private func sendTrackingUpdateNotification(item: ReturnItem, status: TrackingStatus) {
            let content = UNMutableNotificationContent()
            content.title = "📦 Package Update"
            content.body = "Your return to \(item.retailer): \(status.rawValue)"
            content.sound = .default
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "bg_tracking_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    
        // Add this helper method to manually schedule background tasks
        private func manuallyScheduleBackgroundTask() {
            print("🔧 Manually scheduling background task from ScenePhase")
            
            let identifier = "com.jstick.Returns.refresh"
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            
            let request = BGAppRefreshTaskRequest(identifier: identifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("✅ Manual background task scheduled successfully")
                sendScenePhaseNotification("✅ Manual Task Scheduled", body: "Background task scheduled from ScenePhase")
            } catch {
                print("❌ Manual background task scheduling failed: \(error)")
                sendScenePhaseNotification("❌ Manual Schedule Failed", body: "Error: \(error.localizedDescription)")
            }
        }
    
        // Add this helper method to test scene phase changes
        private func sendScenePhaseNotification(_ title: String, body: String) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "scene_phase_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to send scene phase notification: \(error)")
                } else {
                    print("📬 Sent scene phase notification: \(title)")
                }
            }
        }
    }

// Add this import at the top
import UserNotifications
