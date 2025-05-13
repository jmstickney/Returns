//
//  EditReturnView.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import SwiftUI

struct EditReturnView: View {
    @ObservedObject var viewModel: ReturnsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var item: ReturnItem
    
    @State private var productName: String
    @State private var retailer: String
    //@State private var returnDate: Date
    @State private var trackingNumber: String
    @State private var refundAmount: String
    @State private var refundStatus: RefundStatus
    @State private var notes: String
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(viewModel: ReturnsViewModel, item: ReturnItem) {
        self.viewModel = viewModel
        self.item = item
        
        // Initialize state variables with item's values
        _productName = State(initialValue: item.productName)
        _retailer = State(initialValue: item.retailer)
        //_returnDate = State(initialValue: item.returnDate)
        _trackingNumber = State(initialValue: item.trackingNumber ?? "")
        _refundAmount = State(initialValue: String(format: "%.2f", item.refundAmount))
        _refundStatus = State(initialValue: item.refundStatus)
        _notes = State(initialValue: item.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    TextField("Product Name", text: $productName)
                    TextField("Retailer", text: $retailer)
                    //DatePicker("Return Date", selection: $returnDate, displayedComponents: .date)
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
                
                Section(header: Text("Additional Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Return")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveChanges()
                }
            )
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveChanges() {
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
        
        // Create updated item
        var updatedItem = item
        updatedItem.productName = productName
        updatedItem.retailer = retailer
        //updatedItem.returnDate = returnDate
        updatedItem.trackingNumber = trackingNumber.isEmpty ? nil : trackingNumber
        updatedItem.refundAmount = amount
        updatedItem.refundStatus = refundStatus
        updatedItem.notes = notes.isEmpty ? nil : notes
        
        // Update the item
        viewModel.updateItem(updatedItem)
        
        // Dismiss the view
        dismiss()
    }
}
