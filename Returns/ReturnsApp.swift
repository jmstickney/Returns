//
//  ReturnsApp.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import SwiftUI

@main
struct ReturnsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ReturnsViewModel()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var isShowingSplash = true
    @Environment(\.scenePhase) private var scenePhase
    private let refreshTimer = Timer.publish(every: 300, on: .main, in: .common)
                                     .autoconnect()
    
    var body: some Scene {
            WindowGroup {
                ZStack {
                    // inject the shared viewModel
                    ReturnsListView(viewModel: viewModel)
                        .opacity(isShowingSplash ? 0 : 1)
                        // splash onAppear
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isShowingSplash = false
                                }
                            }
                        }
                        // 5️⃣ refresh when the app becomes active
                        .onChange(of: scenePhase) { newPhase in
                            if newPhase == .active {
                                refreshAllTracking()
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
    }


