//
//  TrackingDetailView.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import SwiftUI

struct TrackingDetailView: View {
    @ObservedObject var viewModel: ReturnsViewModel
    var itemID: UUID
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isRefreshing = false
    @State private var preventDismissal = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Item header info
                if let index = viewModel.returnItems.firstIndex(where: { $0.id == itemID }),
                   let trackingNumber = viewModel.returnItems[index].trackingNumber {
                    
                    HStack {
                        Text(trackingNumber)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            refreshTracking()
                        }) {
                            HStack {
                                Text("Refresh")
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isLoading)
                    }
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if let trackingInfo = viewModel.returnItems[index].trackingInfo {
                        // Status card
                        HStack {
                            Image(systemName: TrackingStatus(rawValue: trackingInfo.status.rawValue)?.iconName ?? "questionmark.circle")
                                .font(.largeTitle)
                                .foregroundColor(Color(TrackingStatus(rawValue: trackingInfo.status.rawValue)?.color ?? "gray"))
                            
                            VStack(alignment: .leading) {
                                Text(trackingInfo.status.rawValue)
                                    .font(.headline)
                                
                                if let lastTracked = viewModel.returnItems[index].lastTracked {
                                    Text("Last updated: \(dateFormatter.string(from: lastTracked))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let estimatedDelivery = trackingInfo.estimatedDelivery {
                                    Text("Estimated delivery: \(dateFormatter.string(from: estimatedDelivery))")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Divider with carrier
                        HStack {
                            Divider()
                            Text(trackingInfo.carrier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Divider()
                        }
                        .padding(.vertical)
                        
                        // Timeline of events
                        Text("Tracking History")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(trackingInfo.details) { detail in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(dateFormatter.string(from: detail.date))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text(detail.location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(detail.activity)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                            .padding(.bottom, 4)
                        }
                        
                        if trackingInfo.details.isEmpty {
                            Text("No tracking details available yet.")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "shippingbox.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No tracking information available")
                                .font(.headline)
                            
                            Button(action: {
                                refreshTracking()
                            }) {
                                Text("Check Status")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    Text("No tracking number found")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Tracking Details")
        .onAppear {
            if viewModel.shouldAutoUpdateTracking(for: itemID) && !preventDismissal {
                isRefreshing = true
                refreshTracking()
            }
        }
        .onDisappear {
            // This prevents auto-navigation when returning to this view
            if isRefreshing {
                preventDismissal = true
                isRefreshing = false
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Tracking Error"),
                message: Text(errorMessage ?? "Failed to update tracking information"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func refreshTracking() {
        isLoading = true
        isRefreshing = true

        viewModel.updateTracking(for: itemID) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isRefreshing = false

                switch result {
                case .success:
                    // Tracking info has been updated in-place on the viewModel —
                    // the UI will refresh automatically.
                    break

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}
