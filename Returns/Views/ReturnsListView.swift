//
//  ReturnsListView.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import SwiftUI

struct ReturnsListView: View {
    @StateObject var viewModel: ReturnsViewModel
    @StateObject private var tutorialManager = TutorialManager()
    @StateObject private var gmailAuthManager = GmailAuthManager.shared
    
    @State private var showingAddSheet = false
    @State private var isShowingGmailIntegration = false
    @State private var animateAddButton = false
    @State private var animateGmailButton = false
    
    init(viewModel: ReturnsViewModel = ReturnsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    List {
                        ForEach(viewModel.returnItems) { item in
                            NavigationLink(destination: ReturnDetailView(itemID: item.id, viewModel: viewModel)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.retailer)
                                        .font(.headline)
                                    
                                    HStack {
                                        Text("$\(String(format: "%.2f", item.refundAmount))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Spacer()
                                        
                                        // Tracking status - only display if tracking info exists
                                        if let trackingInfo = item.trackingInfo {
                                            Label {
                                                Text(trackingInfo.status.rawValue)
                                                    .font(.caption)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    
                                            } icon: {
                                                Image(systemName: trackingStatusIcon(for: trackingInfo.status))
                                                    .foregroundColor(trackingStatusColor(for: trackingInfo.status))
                                            }
                                            .padding(4)
                                            .background(trackingStatusColor(for: trackingInfo.status).opacity(0.2))
                                            .cornerRadius(4)
                                        }
                                        
                                        // Refund status
                                        Label {
                                            Text(item.refundStatus.rawValue)
                                                .font(.caption)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                        } icon: {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .foregroundColor(statusColor(for: item.refundStatus))
                                        }
                                        .padding(4)
                                        .background(statusColor(for: item.refundStatus).opacity(0.2))
                                        .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: viewModel.deleteReturn)
                    }
                    
                    // Gmail scan section - always show at bottom
                    VStack(spacing: 16) {
                        if viewModel.returnItems.isEmpty {
                            // Empty state content
                            VStack(spacing: 20) {
                                Button(action: {
                                    showingAddSheet = true
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                }
                                
                                Text("No Returns Yet")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                            }
                        } else {
                            // When list has items, show smaller section
                            VStack(spacing: 12) {
                                Text("Find More Returns")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Scan your email to automatically discover more returns.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Gmail button - always visible
                        Button(action: {
                            isShowingGmailIntegration = true
                        }) {
                            HStack {
                                Image(systemName: gmailAuthManager.isAuthenticated ? "magnifyingglass" : "envelope.fill")
                                Text(gmailAuthManager.isAuthenticated ? "Scan Emails for Returns" : "Connect Gmail")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        // Highlight Gmail button during tutorial
                        .scaleEffect(animateGmailButton ? 1.1 : 1.0)
                        .animation(animateGmailButton ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: animateGmailButton)
                        
                        // Show connection status if authenticated
                        if gmailAuthManager.isAuthenticated {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gmail Connected")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let email = gmailAuthManager.userEmail {
                                        Text(email)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .navigationTitle("My Returns")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddSheet = true
                        }) {
                            Text("Add Return")
                        }
                        // Highlight Add Return button during tutorial
                        .scaleEffect(animateAddButton ? 1.1 : 1.0)
                        .animation(animateAddButton ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: animateAddButton)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
                .sheet(isPresented: $showingAddSheet) {
                    AddReturnView(viewModel: viewModel)
                }
                .sheet(isPresented: $isShowingGmailIntegration) {
                    NavigationView {
                        GmailIntegrationView(viewModel: viewModel)
                            .navigationTitle("Gmail Integration")
                            .navigationBarItems(trailing: Button("Done") {
                                isShowingGmailIntegration = false
                            })
                    }
                }
                .onAppear {
                    // Check for tutorial on every appear (for existing users)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        tutorialManager.startTutorialAfterOnboarding()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
                    // Tutorial should start when onboarding completes (for new users)
                    print("📢 Received onboarding completed notification")
                    tutorialManager.startTutorialWhenReady()
                }
                .onChange(of: tutorialManager.currentStep) { step in
                    // Control button animations based on tutorial step
                    updateButtonAnimations()
                }
                .onChange(of: tutorialManager.showTutorial) { showing in
                    // Stop all animations when tutorial ends
                    if !showing {
                        stopAllAnimations()
                    }
                }
                
                // Tutorial overlay
                if tutorialManager.showTutorial {
                    TutorialOverlay(tutorialManager: tutorialManager)
                }
            }
        }
    }
    
    // MARK: - Tutorial Animation Control
    private func updateButtonAnimations() {
        // Stop all animations first
        stopAllAnimations()
        
        // Start appropriate animation based on current step
        if tutorialManager.showTutorial {
            switch tutorialManager.currentTutorialStep {
            case .addReturn:
                animateAddButton = true
            case .connectGmail:
                animateGmailButton = true
            default:
                break
            }
        }
    }
    
    private func stopAllAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            animateAddButton = false
            animateGmailButton = false
        }
    }
    
    // MARK: - Helper Functions
    func statusColor(for status: RefundStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .shipped: return .blue
        case .received: return .purple
        case .processed: return .green
        case .completed: return .gray
        }
    }
    
    func trackingStatusColor(for status: TrackingStatus) -> Color {
        switch status {
        case .unknown: return .gray
        case .inTransit: return .blue
        case .outForDelivery: return .orange
        case .delivered: return .green
        case .exception: return .red
        case .pending: return .purple
        }
    }
    
    func trackingStatusIcon(for status: TrackingStatus) -> String {
        switch status {
        case .unknown: return "questionmark.circle.fill"
        case .inTransit: return "shippingbox.fill"
        case .outForDelivery: return "truck.fill"
        case .delivered: return "checkmark.circle.fill"
        case .exception: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        }
    }
}

#Preview {
    ReturnsListView()
}
