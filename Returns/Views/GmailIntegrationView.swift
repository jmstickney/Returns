//
//  GmailIntegrationView.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/9/25.
//


// GmailIntegrationView.swift
import SwiftUI
import Combine

struct GmailIntegrationView: View {
    @ObservedObject var authManager = GmailAuthManager.shared
    @ObservedObject var viewModel: ReturnsViewModel
    
    @State private var potentialReturns: [PotentialReturn] = []
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack {
            // Gmail Authentication Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gmail Connection")
                        .font(.headline)
                    
                    if authManager.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Connected")
                                    .fontWeight(.medium)
                                if let email = authManager.userEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button(action: {
                                authManager.logout()
                                potentialReturns = []
                            }) {
                                Text("Disconnect")
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        GmailAuthButton()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // Scan Emails Button
            if authManager.isAuthenticated {
                Button(action: {
                    scanEmails()
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text(isScanning ? "Scanning..." : "Scan Emails for Returns")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .disabled(isScanning)
            }
            
            // Potential Returns List
            if !potentialReturns.isEmpty {
                List {
                        // Sort returns by EMAIL date (newest first) rather than return date
                        ForEach(potentialReturns.sorted(by: { $0.emailDate > $1.emailDate }), id: \.id) { potentialReturn in
                            PotentialReturnRow(potentialReturn: potentialReturn, viewModel: viewModel)
                        }
                }
            } else if isScanning {
                ProgressView("Scanning your emails...")
                    .padding()
            } else if authManager.isAuthenticated {
                VStack {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("Connect and scan your Gmail to automatically find returns")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Gmail Integration")
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func scanEmails() {
        isScanning = true
        potentialReturns = []
        
        EmailScannerService.shared.scanEmailsForReturns()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isScanning = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                    print(error)
                    showError = true
                }
            }, receiveValue: { returns in
                self.potentialReturns = returns
            })
            .store(in: &cancellables)
    }
}

struct PotentialReturnRow: View {
    let potentialReturn: PotentialReturn
    let viewModel: ReturnsViewModel
    
    @State private var isAdding = false
    @State private var isAdded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
//            Text(potentialReturn.productName)
//                .font(.headline)
            
            Text(potentialReturn.retailer)
                .font(.headline)
            
            HStack {
                Text("$\(String(format: "%.2f", potentialReturn.refundAmount))")
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
                Text(formatDate(potentialReturn.emailDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Button(action: {
                        addToReturns()
                    }) {
                        Text(isAdding ? "Adding..." : "Add")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .disabled(isAdding || isAdded)
                }
            }
            
            Text(potentialReturn.emailSubject)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func addToReturns() {
        isAdding = true
        
        // Create a ReturnItem from the potential return
        let returnItem = ReturnItem(
            productName: potentialReturn.productName,
            retailer: potentialReturn.retailer,
            //returnDate: potentialReturn.returnDate,
            trackingNumber: nil, // Can't extract from email
            refundAmount: potentialReturn.refundAmount,
            refundStatus: .pending,
            notes: "Added from email: \(potentialReturn.emailSubject)"
        )
        
        // Add to view model
        viewModel.addReturn(item: returnItem)
        
        // Mark as added
        isAdding = false
        isAdded = true
    }
}
