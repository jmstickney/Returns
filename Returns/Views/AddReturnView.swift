//
//  AddReturnView.swift
//  Returns
//
//  Created by Jonathan Stickney on 2/25/25.
//

import SwiftUI

struct AddReturnView: View {
    @ObservedObject var viewModel: ReturnsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var productName: String = ""
    @State private var retailer: String = ""
    @State private var returnDate: Date = Date()
    @State private var trackingNumber: String = ""
    @State private var refundAmount: String = ""
    @State private var refundStatus: RefundStatus = .pending
    @State private var notes: String = ""
    
    @State private var productImage: UIImage?
    @State private var returnLabelImage: UIImage?
    @State private var packagingImage: UIImage?
    
    @State private var showingImagePicker = false
    @State private var selectedImageType: ImageType?
    @State private var currentImageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingActionSheet = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Field validation states
    @State private var productNameError = false
    @State private var refundAmountError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    // Product Name (Required)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Product Name *", text: $productName)
                            .background(productNameError ? Color.red.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .onChange(of: productName) { _ in
                                if productNameError && !productName.isEmpty {
                                    productNameError = false
                                }
                            }
                        
                        if productNameError {
                            Text("Product name is required")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    TextField("Retailer", text: $retailer)
                    
                    DatePicker("Return Date", selection: $returnDate, displayedComponents: .date)
                }
                
                Section(header: Text("Return Details")) {
                    TextField("Tracking Number (Optional)", text: Binding(
                        get: { trackingNumber },
                        set: { trackingNumber = $0.uppercased() }
                    ))
                    
                    // Refund Amount (Required)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Refund Amount *", text: $refundAmount)
                                .keyboardType(.decimalPad)
                                .background(refundAmountError ? Color.red.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .onChange(of: refundAmount) { _ in
                                    if refundAmountError && !refundAmount.isEmpty {
                                        refundAmountError = false
                                    }
                                }
                        }
                        
                        if refundAmountError {
                            Text("Valid refund amount is required")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Picker("Status", selection: $refundStatus) {
                        ForEach(RefundStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Images")) {
                    ImagePickerRow(
                        title: "Product Image",
                        image: $productImage,
                        showingActionSheet: $showingActionSheet,
                        selectedImageType: $selectedImageType,
                        imageType: .product
                    )
                    
                    ImagePickerRow(
                        title: "Return Label",
                        image: $returnLabelImage,
                        showingActionSheet: $showingActionSheet,
                        selectedImageType: $selectedImageType,
                        imageType: .returnLabel
                    )
                    
                    ImagePickerRow(
                        title: "Packaging",
                        image: $packagingImage,
                        showingActionSheet: $showingActionSheet,
                        selectedImageType: $selectedImageType,
                        imageType: .packaging
                    )
                }
                
                Section(header: Text("Additional Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                // Required fields notice
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Fields marked with * are required")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Return")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveReturn()
                }
                .fontWeight(.semibold)
                .foregroundColor(canSave() ? .blue : .gray)
            )
            .alert("Missing Information", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Select Image Source"),
                    buttons: [
                        .default(Text("Camera")) {
                            self.currentImageSource = .camera
                            self.showingImagePicker = true
                        },
                        .default(Text("Photo Library")) {
                            self.currentImageSource = .photoLibrary
                            self.showingImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: getImageBindingForType(), sourceType: currentImageSource)
            }
        }
    }
    
    // MARK: - Validation Methods
    
    private func canSave() -> Bool {
        return !productName.isEmpty && !refundAmount.isEmpty && Double(refundAmount) != nil
    }
    
    private func validateFields() -> Bool {
        var isValid = true
        
        // Reset error states
        productNameError = false
        refundAmountError = false
        
        // Validate product name
        if productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            productNameError = true
            isValid = false
        }
        
        // Validate refund amount
        if refundAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(refundAmount) == nil || Double(refundAmount)! <= 0 {
            refundAmountError = true
            isValid = false
        }
        
        return isValid
    }
    
    private func getImageBindingForType() -> Binding<UIImage?> {
        guard let type = selectedImageType else {
            return Binding<UIImage?>.constant(nil)
        }
        
        switch type {
        case .product:
            return $productImage
        case .returnLabel:
            return $returnLabelImage
        case .packaging:
            return $packagingImage
        }
    }
    
    private func saveReturn() {
        // Validate all fields
        guard validateFields() else {
            // Show specific error message
            if productNameError {
                alertMessage = "Please enter a product name"
            } else if refundAmountError {
                alertMessage = "Please enter a valid refund amount"
            }
            showAlert = true
            return
        }
        
        // Convert refund amount (we know it's valid from validation)
        let amount = Double(refundAmount)!
        
        // Create the return item
        var newReturn = ReturnItem(
            productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
            retailer: retailer.trimmingCharacters(in: .whitespacesAndNewlines),
            trackingNumber: trackingNumber.isEmpty ? nil : trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            refundAmount: amount,
            refundStatus: refundStatus,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Add the return to get an ID assigned
        viewModel.addReturn(item: newReturn)
        
        // Get the item with its new ID (last item in the array)
        if let returnWithID = viewModel.returnItems.last {
            // Save images if they exist
            if let productImage = productImage {
                viewModel.setImage(productImage, for: .product, itemID: returnWithID.id)
            }
            
            if let returnLabelImage = returnLabelImage {
                viewModel.setImage(returnLabelImage, for: .returnLabel, itemID: returnWithID.id)
            }
            
            if let packagingImage = packagingImage {
                viewModel.setImage(packagingImage, for: .packaging, itemID: returnWithID.id)
            }
        }
        
        dismiss()
    }
}

struct ImagePickerRow: View {
    var title: String
    @Binding var image: UIImage?
    @Binding var showingActionSheet: Bool
    @Binding var selectedImageType: ImageType?
    var imageType: ImageType
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 4)
            
            if let image = image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                    
                    Button(action: {
                        self.image = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            } else {
                Button(action: {
                    selectedImageType = imageType
                    showingActionSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Image")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    AddReturnView(viewModel: ReturnsViewModel())
}
