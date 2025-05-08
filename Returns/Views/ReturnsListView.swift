//
//  ReturnsListView.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import SwiftUI

struct ReturnsListView: View {
    //@StateObject var viewModel = ReturnsViewModel()
    @StateObject var viewModel: ReturnsViewModel
    
    init(viewModel: ReturnsViewModel = ReturnsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
      }
    
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.returnItems) { item in
                    NavigationLink(destination: ReturnDetailView(itemID: item.id, viewModel: viewModel)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.productName)
                                .font(.headline)
                            Text(item.retailer)
                                .font(.subheadline)
                            
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
            .navigationTitle("My Returns")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Text("Add Return")
                        //Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddReturnView(viewModel: viewModel)
            }
        }
    }
    
    func statusColor(for status: RefundStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .shipped:
            return .blue
        case .received:
            return .purple
        case .processed:
            return .green
        case .completed:
            return .gray
        }
    }
    
    func trackingStatusColor(for status: TrackingStatus) -> Color {
        switch status {
        case .unknown:
            return .gray
        case .inTransit:
            return .blue
        case .outForDelivery:
            return .orange
        case .delivered:
            return .green
        case .exception:
            return .red
        case .pending:
            return .purple
        }
    }
    
    func trackingStatusIcon(for status: TrackingStatus) -> String {
        switch status {
        case .unknown:
            return "questionmark.circle.fill"
        case .inTransit:
            return "shippingbox.fill"
        case .outForDelivery:
            return "truck.fill"
        case .delivered:
            return "checkmark.circle.fill"
        case .exception:
            return "exclamationmark.triangle.fill"
        case .pending:
            return "clock.fill"
        }
    }
}

struct ReturnsListView_Previews: PreviewProvider {
    static var previews: some View {
        ReturnsListView()
    }
}
