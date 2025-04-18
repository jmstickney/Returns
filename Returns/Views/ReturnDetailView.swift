//  ReturnDetailView.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import SwiftUI

struct ReturnDetailView: View {
    let itemID: UUID
    @ObservedObject var viewModel: ReturnsViewModel
    @State private var selectedStatus: RefundStatus
    @State private var activeTrackingID: UUID?

    @State private var showingImagePicker = false
    @State private var selectedImageType: ImageType?
    @State private var inputImage: UIImage?

    @State private var showingActionSheet = false
    @State private var currentImageSource: UIImagePickerController.SourceType = .photoLibrary

    @State private var showingEditSheet = false

    init(itemID: UUID, viewModel: ReturnsViewModel) {
        self.itemID = itemID
        self.viewModel = viewModel
        // Initialize selectedStatus from the current model
        let status = viewModel.returnItems.first(where: { $0.id == itemID })?.refundStatus ?? .pending
        _selectedStatus = State(initialValue: status)
    }

    @ViewBuilder
    var body: some View {
        // Lookup the live item in the viewModel by ID
        if let index = viewModel.returnItems.firstIndex(where: { $0.id == itemID }) {
            let item = viewModel.returnItems[index]

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Product Details
                        GroupBox(label: Label("Product Details", systemImage: "cube.box")) {
                            VStack(alignment: .leading, spacing: 8) {
                                DetailRow(title: "Product:", value: item.productName)
                                DetailRow(title: "Retailer:", value: item.retailer)
                                DetailRow(title: "Return Date:", value: formattedDate(item.returnDate))
                                DetailRow(title: "Refund Amount:", value: "$\(String(format: "%.2f", item.refundAmount))")
                            }
                            .padding(.vertical, 8)
                        }

                        // Tracking Information
                        GroupBox(label: Label("Tracking Information", systemImage: "shippingbox")) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let trackingNumber = item.trackingNumber {
                                    DetailRow(title: "Tracking Number:", value: trackingNumber)

                                    if let info = item.trackingInfo {
                                        HStack(spacing: 10) {
                                            Image(systemName: getStatusIcon(for: info.status))
                                                .foregroundColor(getStatusColor(for: info.status))
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(info.status.rawValue)
                                                    .font(.headline)
                                                    .foregroundColor(getStatusColor(for: info.status))
                                                if let last = item.lastTracked {
                                                    Text("Updated \(timeAgoSince(last))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            if let est = info.estimatedDelivery {
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("Estimated Delivery:")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Text(formattedDate(est))
                                                        .font(.caption)
                                                        .bold()
                                                }
                                            }
                                        }
                                        .padding(10)
                                        .background(getStatusColor(for: info.status).opacity(0.1))
                                        .cornerRadius(8)
                                        .padding(.vertical, 4)
                                    }

                                    HStack {
                                        Link("Track on Carrier Website",
                                             destination: URL(string: "https://www.google.com/search?q=\(trackingNumber)")!)
                                            .foregroundColor(.blue)
                                        Spacer()
                                        Button(action: { activeTrackingID = itemID }) {
                                            HStack {
                                                Text("View Tracking")
                                                Image(systemName: "chevron.right")
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }

                                    if let info = item.trackingInfo {
                                        HStack {
                                            Image(systemName: TrackingStatus(rawValue: info.status.rawValue)?.iconName ?? "questionmark.circle")
                                                .foregroundColor(Color(TrackingStatus(rawValue: info.status.rawValue)?.color ?? "gray"))
                                            Text(info.status.rawValue)
                                                .font(.subheadline)
                                                .foregroundColor(Color(TrackingStatus(rawValue: info.status.rawValue)?.color ?? "gray"))
                                            Spacer()
                                            if let last = item.lastTracked {
                                                Text(timeAgoSince(last))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                } else {
                                    Text("No tracking number available")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // Refund Status
                        GroupBox(label: Label("Refund Status", systemImage: "dollarsign.circle")) {
                            Picker("Status", selection: $selectedStatus) {
                                ForEach(RefundStatus.allCases) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedStatus) { newStatus in
                                viewModel.updateStatus(for: item, newStatus: newStatus)
                            }
                            .padding(.vertical, 8)
                        }

                        // Reminders
                        ReminderSectionView(viewModel: viewModel, itemID: itemID)

                        // Images
                        GroupBox(label: Label("Images", systemImage: "photo.on.rectangle")) {
                            VStack(spacing: 16) {
                                ImageSectionRow(title: "Product Image", imageType: .product, itemID: itemID, viewModel: viewModel, showingActionSheet: $showingActionSheet, selectedImageType: $selectedImageType)
                                Divider()
                                ImageSectionRow(title: "Return Label", imageType: .returnLabel, itemID: itemID, viewModel: viewModel, showingActionSheet: $showingActionSheet, selectedImageType: $selectedImageType)
                                Divider()
                                ImageSectionRow(title: "Packaging", imageType: .packaging, itemID: itemID, viewModel: viewModel, showingActionSheet: $showingActionSheet, selectedImageType: $selectedImageType)
                            }
                            .padding(.vertical, 8)
                        }

                        // Notes
                        if let notes = item.notes, !notes.isEmpty {
                            GroupBox(label: Label("Notes", systemImage: "note.text")) {
                                Text(notes)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding()
                }

                // Hidden NavigationLink for TrackingDetailView
                NavigationLink(tag: itemID, selection: $activeTrackingID) {
                    TrackingDetailView(viewModel: viewModel, itemID: itemID)
                } label: {
                    EmptyView()
                }
                .hidden()
            }
            .navigationTitle("Return Details")
            .navigationBarItems(trailing: Button("Edit") { showingEditSheet = true })
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(title: Text("Select Image Source"), buttons: [
                    .default(Text("Camera")) { currentImageSource = .camera; showingImagePicker = true },
                    .default(Text("Photo Library")) { currentImageSource = .photoLibrary; showingImagePicker = true },
                    .cancel()
                ])
            }
            .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
                ImagePicker(selectedImage: $inputImage, sourceType: currentImageSource)
            }
            .sheet(isPresented: $showingEditSheet) {
                EditReturnView(viewModel: viewModel, item: item)
            }
        } else {
            Text("Item not found")
                .foregroundColor(.secondary)
                .navigationTitle("Return Details")
        }
    }

    // MARK: - Helpers
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func loadImage() {
        guard let type = selectedImageType, let img = inputImage else { return }
        viewModel.setImage(img, for: type, itemID: itemID)
        inputImage = nil
    }

    func timeAgoSince(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        if let day = components.day, day >= 1 { return day == 1 ? "1 day ago" : "\(day) days ago" }
        if let hour = components.hour, hour >= 1 { return hour == 1 ? "1 hour ago" : "\(hour) hours ago" }
        if let minute = components.minute, minute >= 1 { return minute == 1 ? "1 minute ago" : "\(minute) minutes ago" }
        return "Just now"
    }
}


// MARK: - Subviews
struct DetailRow: View {
    var title: String
    var value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(title).fontWeight(.medium).frame(width: 100, alignment: .leading)
            Text(value).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ImageSectionRow: View {
    var title: String
    var imageType: ImageType
    var itemID: UUID
    var viewModel: ReturnsViewModel
    @Binding var showingActionSheet: Bool
    @Binding var selectedImageType: ImageType?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).fontWeight(.medium)
            if let image = viewModel.getImage(for: imageType, itemID: itemID) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image).resizable().scaledToFit().cornerRadius(8)
                    Button(action: { viewModel.setImage(nil, for: imageType, itemID: itemID) }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Color.black.opacity(0.6)).clipShape(Circle())
                    }
                    .padding(8)
                }
            } else {
                Button(action: { selectedImageType = imageType; showingActionSheet = true }) {
                    HStack { Image(systemName: "plus"); Text("Add Image") }
                        .frame(maxWidth: .infinity).padding().background(Color.gray.opacity(0.2)).cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Preview
struct ReturnDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = ReturnItem(productName: "Headphones", retailer: "Electronics Store", returnDate: Date(), trackingNumber: "1Z999AA10123456784", refundAmount: 79.99, refundStatus: .shipped, notes: "Color was different than expected.")
        let vm = ReturnsViewModel()
        return NavigationView { ReturnDetailView(itemID: sample.id, viewModel: vm) }
    }
}

// MARK: - Helpers for Tracking Status
func getStatusIcon(for status: TrackingStatus) -> String {
    switch status {
    case .unknown:        return "questionmark.circle"
    case .inTransit:      return "shippingbox"
    case .outForDelivery: return "truck"
    case .delivered:      return "checkmark.circle.fill"
    case .exception:      return "exclamationmark.triangle"
    case .pending:        return "clock"
    }
}

func getStatusColor(for status: TrackingStatus) -> Color {
    switch status {
    case .unknown:        return .gray
    case .inTransit:      return .blue
    case .outForDelivery: return .orange
    case .delivered:      return .green
    case .exception:      return .red
    case .pending:        return .purple
    }
}
