//
//  BackgroundTestView.swift
//  Returns
//
//  Created by Jonathan Stickney on 6/6/25.
//


import SwiftUI
import BackgroundTasks
import UserNotifications

#if DEBUG
struct BackgroundTestView: View {
    @State private var testResults: [String] = []
    @State private var isTestingInProgress = false
    @State private var notificationsEnabled = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🧪 Background Task Tester")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Test email scanning in background")
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
                    
                    // Test Buttons
                    VStack(spacing: 16) {
                        Group {
                            TestButton(
                                title: "🧪 Test Email Scan Now",
                                subtitle: "Run email scan immediately",
                                action: testEmailScanNow,
                                disabled: isTestingInProgress,
                                color: .blue
                            )
                            
                            TestButton(
                                title: "📅 Schedule Background Task", 
                                subtitle: "Schedule for when app goes to background",
                                action: scheduleBackgroundTask,
                                disabled: false,
                                color: .green
                            )
                            
                            TestButton(
                                title: "🔔 Test Notification",
                                subtitle: "Send a simple test notification",
                                action: testNotification,
                                disabled: false,
                                color: .purple
                            )
                            
                            TestButton(
                                title: "🗑️ Clear Test Results",
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
    
    // MARK: - Test Actions
    
    private func testEmailScanNow() {
        addLog("🧪 Starting immediate email scan test...")
        isTestingInProgress = true
        
        // Use the new shared property instead
        guard let appDelegate = AppDelegate.shared else {
            addLog("❌ Could not access AppDelegate")
            isTestingInProgress = false
            return
        }
        
        appDelegate.testBackgroundEmailScan()
        addLog("✅ Email scan test initiated")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isTestingInProgress = false
            addLog("🏁 Test completed")
        }
    }
    
    private func scheduleBackgroundTask() {
        addLog("📅 Scheduling background task...")
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            addLog("❌ Could not access AppDelegate")
            return
        }
        
        appDelegate.forceBackgroundTaskExecution()
        addLog("✅ Background task scheduled")
        addLog("💡 Put app in background or use Xcode debugger to trigger")
    }
    
    private func testNotification() {
        addLog("🔔 Sending test notification...")
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This is a simple test notification to verify notifications are working"
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
                    self.addLog("✅ Test notification sent")
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

// MARK: - Supporting Views

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
            Text("🎯 Testing Instructions")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: "1", text: "Test immediate email scan first")
                InstructionRow(number: "2", text: "Schedule background task") 
                InstructionRow(number: "3", text: "Put app in background")
                InstructionRow(number: "4", text: "Wait for notifications OR use Xcode debugger")
            }
            
            Text("Xcode Debugger Command:")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.top, 8)
            
            Text("e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"com.jstick.Returns.refresh\"]")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(4)
                .textSelection(.enabled)
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

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Preview

struct BackgroundTestView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundTestView()
    }
}

#endif

// MARK: - Integration Instructions

/*
TO ADD THIS TO YOUR APP:

1. Create a new Swift file called "BackgroundTestView.swift"
2. Copy this entire code into that file
3. Add a way to access it from your main app (see below)

ADD TO YOUR ReturnsListView:

#if DEBUG
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        NavigationLink("🧪 Test", destination: BackgroundTestView())
    }
}
#endif

OR ADD A BUTTON ANYWHERE:

#if DEBUG
Button("🧪 Test Background Tasks") {
    // Present the test view
}
.sheet(isPresented: $showingTestView) {
    BackgroundTestView()
}
#endif
*/
