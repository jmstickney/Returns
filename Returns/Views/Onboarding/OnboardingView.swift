//
//  OnboardingView.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/21/25.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var currentPage = 0
    
    // Track notification permission state
    @State private var notificationPermissionRequested = false
    @State private var notificationPermissionGranted = false
    
    // Content for each page
    private let pages = [
        OnboardingPage(
            title: "Welcome to Refund Radar",
            subtitle: "Never lose track of returns again",
            description: "",
            imageName: "arrow.triangle.2.circlepath.circle",
            backgroundColor: Color.blue
        ),
        OnboardingPage(
            title: "Track Your Returns",
            subtitle: "Keep all your returns organized in one place",
            description: "Add products you're returning, set reminders, and track refund status so you never lose money on returns again.",
            imageName: "cube.box.fill",
            backgroundColor: Color.blue
        ),
        OnboardingPage(
            title: "Scan Gmail for Returns",
            subtitle: "Automatically find returns in your email",
            description: "Connect your Gmail account to automatically detect purchases and returns from your inbox.",
            imageName: "envelope.fill",
            backgroundColor: Color.red
        ),
        OnboardingPage(
            title: "Get Reminders & Updates",
            subtitle: "Never miss a return deadline",
            description: "Receive notifications for return deadlines and track shipping status to ensure your returns are processed correctly.",
            imageName: "bell.fill",
            backgroundColor: Color.orange
        ),
        OnboardingPage(
            title: "You're all set!",
            subtitle: "Start tracking your returns and get your money back",
            description: "",
            imageName: "checkmark.circle.fill",
            backgroundColor: Color.green
        )
    ]
    
    var body: some View {
        ZStack {
            // Background color
            pages[currentPage].backgroundColor
                .ignoresSafeArea()
            
            // Add TabView for swipe functionality
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 20) {
                        // Skip button at top right (except on first and last pages)
                        if index > 0 && index < pages.count - 1 {
                            HStack {
                                Spacer()
                                Button(action: {
                                    onboardingManager.completeOnboarding()
                                }) {
                                    Text("Skip")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.trailing, 20)
                                .padding(.top, 20)
                            }
                        }
                        
                        Spacer()
                        
                        // Page content
                        if index == 0 {
                            // Welcome page
                            Image(systemName: pages[index].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white)
                            
                            Text(pages[index].title)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.top, 20)
                            
                            Text(pages[index].subtitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 10)
                        } else if index == pages.count - 1 {
                            // Final page
                            Image(systemName: pages[index].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white)
                            
                            Text(pages[index].title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(pages[index].subtitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            Button(action: {
                                onboardingManager.completeOnboarding()
                            }) {
                                Text("Get Started")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(height: 55)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                    .padding(.horizontal, 30)
                            }
                            .padding(.top, 30)
                        } else {
                            // Standard content page
                            Image(systemName: pages[index].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white)
                            
                            Text(pages[index].title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(pages[index].subtitle)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(pages[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            // Special notification UI for the notifications page
                            if index == 3 {
                                if notificationPermissionRequested && notificationPermissionGranted {
                                    // Successfully enabled
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        
                                        Text("Notifications enabled!")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                    .padding(.top, 20)
                                } else if notificationPermissionRequested && !notificationPermissionGranted {
                                    // Permission was denied
                                    VStack {
                                        HStack {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundColor(.yellow)
                                            
                                            Text("Notifications are disabled")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Button(action: {
                                            openSettings()
                                        }) {
                                            Text("Open Settings to Enable")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                        }
                                        .padding(.top, 10)
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                    .padding(.top, 20)
                                } else {
                                    // Not yet requested - show button
                                    Button(action: {
                                        requestNotificationPermission()
                                    }) {
                                        HStack {
                                            Image(systemName: "bell.badge.fill")
                                            Text("Enable Notifications")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 250)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                        .shadow(radius: 3)
                                    }
                                    .padding(.top, 20)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Page indicators (moved out of TabView)
                        HStack(spacing: 8) {
                            ForEach(0..<pages.count) { pageIndex in
                                Circle()
                                    .fill(index == pageIndex ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // Navigation buttons
                        if index == 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage = 1
                                }
                            }) {
                                Text("Get Started")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(height: 55)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                                    .padding(.horizontal, 30)
                            }
                            .padding(.bottom, 50)
                        } else if index < pages.count - 1 {
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        currentPage = max(0, currentPage - 1)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        currentPage = min(pages.count - 1, currentPage + 1)
                                    }
                                }) {
                                    HStack {
                                        Text("Next")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.bottom, 30)
                        }
                    }
                    .tag(index)
                    .onAppear {
                        if index == 3 {
                            // When the notifications page appears, check current status
                            checkNotificationStatus()
                            
                            // Auto-request if first time seeing this page and app hasn't requested before
                            if !onboardingManager.hasRequestedNotificationPermission {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    requestNotificationPermission()
                                }
                            }
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Hide the default indicators
            .animation(.easeInOut, value: currentPage)
        }
        .onAppear {
            // Check initial notification status
            checkNotificationStatus()
        }
    }
    
    // Request notification permission via OnboardingManager
    private func requestNotificationPermission() {
        onboardingManager.requestNotificationPermission { granted in
            notificationPermissionRequested = true
            notificationPermissionGranted = granted
        }
    }
    
    // Check current notification status
    private func checkNotificationStatus() {
        onboardingManager.checkNotificationStatus { granted in
            notificationPermissionRequested = onboardingManager.hasRequestedNotificationPermission
            notificationPermissionGranted = granted
        }
    }
    
    // Function to open app settings
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
    }
}

// Helper struct for page content
struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let backgroundColor: Color
}

// Preview provider for SwiftUI previews
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onboardingManager: OnboardingManager())
    }
}
