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
    
    @State private var showingAddSheet = false
    @State private var isShowingGmailIntegration = false
    
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
                    
                    // Gmail Connect Button (shown when list is empty)
                    if viewModel.returnItems.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            
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
                            
                            Text("Add returns manually ☝️ or scan your email.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Button(action: {
                                isShowingGmailIntegration = true
                            }) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Connect Gmail")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.top)
                            // Highlight Gmail button during tutorial
                            .scaleEffect(tutorialManager.showTutorial && tutorialManager.currentTutorialStep == .connectGmail ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                     value: tutorialManager.showTutorial && tutorialManager.currentTutorialStep == .connectGmail)
                            
                            Spacer()
                        }
                        .padding()
                    }
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
                        .scaleEffect(tutorialManager.showTutorial && tutorialManager.currentTutorialStep == .addReturn ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                 value: tutorialManager.showTutorial && tutorialManager.currentTutorialStep == .addReturn)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack {
                            EditButton()
                            
                            // Gmail button in toolbar
                            if !viewModel.returnItems.isEmpty {
                                Button(action: {
                                    isShowingGmailIntegration = true
                                }) {
                                    Image(systemName: "envelope.badge")
                                }
                                // Highlight Gmail toolbar button during tutorial (when list has items)
                                .scaleEffect(tutorialManager.showTutorial && tutorialManager.currentTutorialStep == .connectGmail ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                         value: tutorialManager.showTutorial && tutorialManager.currentTutorialStep == .connectGmail)
                            }
                        }
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
                    // Only start tutorial after onboarding is complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        tutorialManager.startTutorialAfterOnboarding()
                    }
                }
                
                // Tutorial overlay
                if tutorialManager.showTutorial {
                    TutorialOverlay(tutorialManager: tutorialManager)
                }
            }
        }
    }
    
    // Your existing helper functions remain the same...
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
