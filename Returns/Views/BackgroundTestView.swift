//
//  BackgroundTestView.swift
//  Returns
//
//  Created by Jonathan Stickney on 6/6/25.
//

import SwiftUI
import BackgroundTasks
import UserNotifications
import Combine

#if DEBUG
struct BackgroundTestView: View {
    @State private var testResults: [String] = []
    @State private var isTestingInProgress = false
    @State private var notificationsEnabled = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🧪 Background Task Tester")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Test email scanning and tracking updates")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Status Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        StatusCard(
                            title: "Gmail",
                            status: GmailAuthManager.shared.isAuthenticated ? "Connected" : "Not Connected",
                            color: GmailAuthManager.shared.isAuthenticated ? .green : .red,
                            icon: "envelope.fill"
                        )
                        
                        StatusCard(
                            title: "Notifications",
                            status: notificationsEnabled ? "Enabled" : "Disabled",
                            color: notificationsEnabled ? .green : .red,
                            icon: "bell.fill"
                        )
                        
                        StatusCard(
                            title: "Background Refresh",
                            status: backgroundRefreshStatus,
                            color: backgroundRefreshColor,
                            icon: "arrow.clockwise"
                        )
                        
                        StatusCard(
                            title: "Test Status",
                            status: isTestingInProgress ? "Running" : "Ready",
                            color: isTestingInProgress ? .orange : .blue,
                            icon: "play.fill"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Test Buttons - DIRECT IMPLEMENTATION
                    VStack(spacing: 16) {
                        Group {
                            TestButton(
                                title: "🔔 Test Notifications",
                                subtitle: "Send a simple test notification",
                                action: testNotification,
                                disabled: false,
                                color: .purple
                            )
                            
                            TestButton(
                                title: "📧 Test Email Scan",
                                subtitle: "Scan emails directly (no AppDelegate)",
                                action: testEmailScanDirect,
                                disabled: isTestingInProgress,
                                color: .blue
                            )
                            
                            TestButton(
                                title: "📦 Test Tracking Updates",
                                subtitle: "Update package tracking directly",
                                action: testTrackingUpdatesDirect,
                                disabled: isTestingInProgress,
                                color: .green
                            )
                            
                            TestButton(
                                title: "🚀 Test Full Process",
                                subtitle: "Run complete background simulation",
                                action: testFullProcessDirect,
                                disabled: isTestingInProgress,
                                color: .orange
                            )
                            
                            TestButton(
                                title: "🧪 Test Background Scheduling",
                                subtitle: "Test BGTaskScheduler directly",
                                action: testBackgroundSchedulingDirect,
                                disabled: false,
                                color: .orange
                            )
                            
                            TestButton(
                                title: "🗑️ Clear Results",
                                subtitle: "Clear the log below",
                                action: clearResults,
                                disabled: testResults.isEmpty,
                                color: .red
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Instructions
                    InstructionsCard()
                    
                    // Test Results Log
                    if !testResults.isEmpty {
                        TestLogView(results: testResults)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            checkNotificationPermissions()
        }
    }
    
    // MARK: - Status Properties
    
    private var backgroundRefreshStatus: String {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: return "Available"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
    
    private var backgroundRefreshColor: Color {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: return .green
        case .denied, .restricted: return .red
        @unknown default: return .gray
        }
    }
    
    // MARK: - DIRECT TEST ACTIONS (No AppDelegate dependency)
    
    private func testNotification() {
        addLog("🔔 Sending test notification...")
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "Notifications are working correctly!"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_notification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("❌ Failed to send notification: \(error.localizedDescription)")
                } else {
                    self.addLog("✅ Test notification sent successfully")
                }
            }
        }
    }
    
    private func testEmailScanDirect() {
        addLog("📧 Starting direct email scan test...")
        isTestingInProgress = true
        
        guard GmailAuthManager.shared.isAuthenticated else {
            addLog("❌ Gmail not authenticated - connect Gmail first")
            isTestingInProgress = false
            return
        }
        
        EmailScannerService.shared.scanEmailsForReturns()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isTestingInProgress = false
                    switch completion {
                    case .finished:
                        self.addLog("✅ Email scan completed successfully")
                    case .failure(let error):
                        self.addLog("❌ Email scan failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { potentialReturns in
                    self.addLog("📧 Found \(potentialReturns.count) potential returns")
                    
                    // Filter new returns
                    let newReturns = potentialReturns.filter { potentialReturn in
                        !EmailFilterManager.shared.isEmailHidden(potentialReturn.emailId) &&
                        !UserDefaults.standard.bool(forKey: "added_\(potentialReturn.emailId)")
                    }
                    
                    if !newReturns.isEmpty {
                        self.addLog("📧 \(newReturns.count) new returns found")
                        self.sendEmailFoundNotification(count: newReturns.count)
                    } else {
                        self.addLog("📧 No new returns (all already processed)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func testTrackingUpdatesDirect() {
        addLog("📦 Starting direct tracking updates test...")
        isTestingInProgress = true
        
        // Load returns from UserDefaults directly
        guard let data = UserDefaults.standard.data(forKey: "ReturnItems"),
              let returnItems = try? JSONDecoder().decode([ReturnItem].self, from: data) else {
            addLog("❌ No return items found")
            isTestingInProgress = false
            return
        }
        
        // Filter items that need updates
        let itemsToUpdate = returnItems.filter { item in
            item.trackingNumber != nil && !item.trackingNumber!.isEmpty
        }
        
        guard !itemsToUpdate.isEmpty else {
            addLog("❌ No items with tracking numbers found")
            isTestingInProgress = false
            return
        }
        
        addLog("📦 Found \(itemsToUpdate.count) items to check")
        
        let group = DispatchGroup()
        var updatesFound = 0
        
        for item in itemsToUpdate.prefix(3) { // Test max 3 items
            guard let trackingNumber = item.trackingNumber else { continue }
            
            group.enter()
            TrackingService.shared.fetchTrackingInfo(trackingNumber: trackingNumber) { result in
                defer { group.leave() }
                
                switch result {
                case .success(let trackingInfo):
                    DispatchQueue.main.async {
                        self.addLog("✅ Updated \(item.retailer): \(trackingInfo.status.rawValue)")
                        updatesFound += 1
                        
                        // Send notification for this update
                        self.sendTrackingUpdateNotification(item: item, status: trackingInfo.status)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.addLog("❌ Failed to update \(item.retailer): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            self.isTestingInProgress = false
            self.addLog("📦 Tracking test complete: \(updatesFound) updates")
        }
    }
    
    private func testFullProcessDirect() {
        addLog("🚀 Starting full background process simulation...")
        isTestingInProgress = true
        
        let group = DispatchGroup()
        
        // Test 1: Email scanning
        if GmailAuthManager.shared.isAuthenticated {
            group.enter()
            addLog("📧 Running email scan...")
            testEmailScanDirectInternal {
                group.leave()
            }
        }
        
        // Test 2: Tracking updates
        group.enter()
        addLog("📦 Running tracking updates...")
        testTrackingUpdatesDirectInternal {
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isTestingInProgress = false
            self.addLog("🎯 Full background process simulation complete!")
            self.sendTestCompleteNotification()
        }
    }
    
    // MARK: - Helper Methods
    
    private func testEmailScanDirectInternal(completion: @escaping () -> Void) {
        EmailScannerService.shared.scanEmailsForReturns()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in completion() },
                receiveValue: { returns in
                    self.addLog("📧 Internal scan: \(returns.count) returns found")
                }
            )
            .store(in: &cancellables)
    }
    
    private func testTrackingUpdatesDirectInternal(completion: @escaping () -> Void) {
        // Simplified tracking test
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async {
                self.addLog("📦 Internal tracking: Simulated update complete")
                completion()
            }
        }
    }
    
    private func sendEmailFoundNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "📧 Test: New Returns Found"
        content.body = "Found \(count) potential returns in test scan"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_email_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    private func sendTrackingUpdateNotification(item: ReturnItem, status: TrackingStatus) {
        let content = UNMutableNotificationContent()
        content.title = "📦 Test: Package Update"
        content.body = "Test update for \(item.retailer): \(status.rawValue)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_tracking_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    private func sendTestCompleteNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Background Test Complete"
        content.body = "Full background process simulation finished successfully"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_complete_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    private func testBackgroundSchedulingDirect() {
        addLog("🧪 Testing background task scheduling directly...")
        
        // Send immediate test notification
        sendSimpleNotification("🧪 Testing Scheduling", body: "About to test background task scheduling")
        
        // Try to schedule a background task directly
        let identifier = "com.jstick.Returns.refresh"
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute for testing
        
        do {
            try BGTaskScheduler.shared.submit(request)
            addLog("✅ Background task scheduling successful")
            sendSimpleNotification("✅ Scheduling Success", body: "Background task was scheduled successfully")
        } catch {
            addLog("❌ Background task scheduling failed: \(error.localizedDescription)")
            sendSimpleNotification("❌ Scheduling Failed", body: "Error: \(error.localizedDescription)")
            
            // More detailed error info
            if let bgError = error as? BGTaskScheduler.Error {
                addLog("BGTaskScheduler Error Code: \(bgError.code.rawValue)")
                addLog("BGTaskScheduler Error: \(bgError.localizedDescription)")
                
                switch bgError.code {
                case .unavailable:
                    addLog("💡 Background tasks unavailable - check device settings")
                case .tooManyPendingTaskRequests:
                    addLog("💡 Too many pending task requests")
                case .notPermitted:
                    addLog("💡 Background refresh not permitted by user")
                default:
                    addLog("💡 Unknown BGTaskScheduler error")
                }
            }
        }
    }
    
    private func sendSimpleNotification(_ title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "simple_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.addLog("❌ Failed to send notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func clearResults() {
        testResults.removeAll()
        addLog("🧹 Results cleared")
    }
    
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.timeOnlyFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.testResults.append(logMessage)
            
            // Keep only last 20 messages
            if self.testResults.count > 20 {
                self.testResults.removeFirst()
            }
        }
    }
}

// MARK: - Supporting Views (same as before)

struct StatusCard: View {
    let title: String
    let status: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(status)
                .font(.caption2)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TestButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    let disabled: Bool
    let color: Color
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(disabled ? Color.gray : color)
            .cornerRadius(12)
        }
        .disabled(disabled)
    }
}

struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 Direct Testing")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: "1", text: "Test notifications first")
                InstructionRow(number: "2", text: "Test email scanning (requires Gmail)")
                InstructionRow(number: "3", text: "Test tracking updates (requires returns)")
                InstructionRow(number: "4", text: "Test full process for complete simulation")
            }
            
            Text("✅ These tests work without AppDelegate!")
                .font(.caption)
                .foregroundColor(.green)
                .fontWeight(.medium)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct TestLogView: View {
    let results: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📋 Test Log")
                .font(.headline)
                .fontWeight(.bold)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(results.enumerated().reversed()), id: \.offset) { index, result in
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 1)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

extension DateFormatter {
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct BackgroundTestView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundTestView()
    }
}

#endif
