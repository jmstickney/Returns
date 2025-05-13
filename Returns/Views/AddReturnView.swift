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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    TextField("Product Name", text: $productName)
                    TextField("Retailer", text: $retailer)
                    DatePicker("Return Date", selection: $returnDate, displayedComponents: .date)
                }
                
                Section(header: Text("Return Details")) {
                    TextField("Tracking Number (Optional)", text: Binding(
                        get: { trackingNumber },
                        set: { trackingNumber = $0.uppercased() }
                    ))
                    TextField("Refund Amount", text: $refundAmount)
                        .keyboardType(.decimalPad)
                    
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
            }
            .navigationTitle("Add Return")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveReturn()
                }
            )
            .alert("Error", isPresented: $showAlert) {
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
        // Validate inputs
        guard !productName.isEmpty else {
            alertMessage = "Please enter a product name"
            showAlert = true
            return
        }
        
        guard !retailer.isEmpty else {
            alertMessage = "Please enter a retailer name"
            showAlert = true
            return
        }
        
        guard let amount = Double(refundAmount) else {
            alertMessage = "Please enter a valid refund amount"
            showAlert = true
            return
        }
        
        // Create the return item
        var newReturn = ReturnItem(
            productName: productName,
            retailer: retailer,
            //returnDate: returnDate,
            trackingNumber: trackingNumber.isEmpty ? nil : trackingNumber,
            refundAmount: amount,
            refundStatus: refundStatus,
            notes: notes.isEmpty ? nil : notes
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

struct AddReturnView_Previews: PreviewProvider {
    static var previews: some View {
        AddReturnView(viewModel: ReturnsViewModel())
    }
}
