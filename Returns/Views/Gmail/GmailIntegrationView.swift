//
//  GmailIntegrationView.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/9/25.
//

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
    @State private var showingEmailPreview = false
    
    // Check if this return has already been added
    private var isAlreadyAdded: Bool {
        return UserDefaults.standard.bool(forKey: "added_\(potentialReturn.emailId)")
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top) {
            // Content section
            VStack(alignment: .leading, spacing: 8) {
                
                Text(potentialReturn.retailer)
                    .font(.headline)
                
                HStack {
                    Text("$\(String(format: "%.2f", potentialReturn.refundAmount))")
                        .font(.caption)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(dateFormatter.string(from: potentialReturn.emailDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(cleanedSubject)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Preview "button" (actually a view with gesture)
            VStack(spacing: 2) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 16))
                Text("Preview")
                    .font(.caption2)
            }
            .frame(width: 60, height: 50)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .foregroundColor(.primary)
            .onTapGesture {
                print("Preview tapped")
                showingEmailPreview = true
            }
            .padding(.horizontal, 4)
            
            // Add "button" (actually a view with gesture)
            Group {
                if isAlreadyAdded {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16))
                        Text("Added")
                            .font(.caption2)
                    }
                    .frame(width: 60, height: 50)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.green)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: isAdding ? "hourglass" : "plus")
                            .font(.system(size: 16))
                        Text(isAdding ? "..." : "Add")
                            .font(.caption2)
                    }
                    .frame(width: 60, height: 50)
                    .background(isAdding ? Color.gray : Color.blue)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .onTapGesture {
                        print("Add tapped")
                        addToReturns()
                    }
                    .opacity(isAdding ? 0.7 : 1.0)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 12)
        .sheet(isPresented: $showingEmailPreview) {
            EmailPreviewView(potentialReturn: potentialReturn)
        }
    }
    
    // Clean the subject text for display
    private var cleanedSubject: String {
        return cleanText(potentialReturn.emailSubject)
    }
    
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Decode HTML entities
        cleaned = decodeHtmlEntities(cleaned)
        
        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func decodeHtmlEntities(_ text: String) -> String {
        var decoded = text
        
        let htmlEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#x27;": "'",
            "&hellip;": "…",
            "&mdash;": "—",
            "&ndash;": "–"
        ]
        
        for (entity, replacement) in htmlEntities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }
        
        return decoded
    }
    
    private func addToReturns() {
        guard !isAdding && !isAlreadyAdded else { return }
        
        isAdding = true
        
        // Create a ReturnItem from the potential return
        let returnItem = ReturnItem(
            productName: potentialReturn.productName,
            retailer: potentialReturn.retailer,
            trackingNumber: nil,
            refundAmount: potentialReturn.refundAmount,
            refundStatus: .pending,
            notes: "Added from email: \(potentialReturn.emailSubject)"
        )
        
        // Add to view model
        viewModel.addReturn(item: returnItem)
        
        // Mark as added
        isAdding = false
        
        // Store the emailId so the app remembers this item has been added
        UserDefaults.standard.set(true, forKey: "added_\(potentialReturn.emailId)")
    }
}
    
struct EmailPreviewView: View {
    let potentialReturn: PotentialReturn
    @Environment(\.presentationMode) private var presentationMode
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Email header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cleanedSubject)
                            .font(.headline)
                        
                        Text("From: \(potentialReturn.retailer)")
                            .font(.subheadline)
                        
                        Text("Date: \(dateFormatter.string(from: potentialReturn.emailDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Email snippet with proper escaping
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Preview")
                            .font(.headline)
                        
                        Text(cleanedSnippet)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .textSelection(.enabled) // Allow text selection for easier reading
                    }
                    
                    // Return details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Return Details")
                            .font(.headline)
                        
                        EmailDetailRow(label: "Product", value: cleanedProductName)
                        EmailDetailRow(label: "Retailer", value: potentialReturn.retailer)
                        EmailDetailRow(label: "Amount", value: "$\(String(format: "%.2f", potentialReturn.refundAmount))")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Email Details")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // MARK: - Text Cleaning Methods
    
    private var cleanedSubject: String {
        return cleanText(potentialReturn.emailSubject)
    }
    
    private var cleanedSnippet: String {
        return cleanText(potentialReturn.emailSnippet)
    }
    
    private var cleanedProductName: String {
        return cleanText(potentialReturn.productName)
    }
    
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Decode HTML entities
        cleaned = decodeHtmlEntities(cleaned)
        
        // Remove excessive whitespace and newlines
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\n+", with: "\n", options: .regularExpression)
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func decodeHtmlEntities(_ text: String) -> String {
        var decoded = text
        
        // Common HTML entities
        let htmlEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&hellip;": "\u{2026}", // …
            "&mdash;": "\u{2014}",  // —
            "&ndash;": "\u{2013}",  // –
            "&ldquo;": "\u{201C}",  // "
            "&rdquo;": "\u{201D}",  // "
            "&lsquo;": "\u{2018}",  // '
            "&rsquo;": "\u{2019}",  // '
            "&bull;": "\u{2022}",   // •
            "&middot;": "\u{00B7}", // ·
            "&copy;": "\u{00A9}",   // ©
            "&reg;": "\u{00AE}",    // ®
            "&trade;": "\u{2122}"   // ™
        ]
        
        for (entity, replacement) in htmlEntities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Decode numeric HTML entities (&#123; and &#x1F;)
        decoded = decodeNumericHtmlEntities(decoded)
        
        return decoded
    }
    
    private func decodeNumericHtmlEntities(_ text: String) -> String {
        var result = text
        
        // Handle decimal entities (&#123;)
        while let range = result.range(of: #"&#\d+;"#, options: .regularExpression) {
            let match = String(result[range])
            let numberString = String(match.dropFirst(2).dropLast(1))
            
            if let number = Int(numberString), let scalar = UnicodeScalar(number) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                // If we can't convert, just remove the entity to prevent infinite loop
                result.replaceSubrange(range, with: "")
            }
        }
        
        // Handle hexadecimal entities (&#x1F;)
        while let range = result.range(of: #"&#x[0-9A-Fa-f]+;"#, options: .regularExpression) {
            let match = String(result[range])
            let hexString = String(match.dropFirst(3).dropLast(1))
            
            if let number = Int(hexString, radix: 16), let scalar = UnicodeScalar(number) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                // If we can't convert, just remove the entity to prevent infinite loop
                result.replaceSubrange(range, with: "")
            }
        }
        
        return result
    }
}

// Enhanced EmailDetailRow with better text handling
struct EmailDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled) // Allow text selection
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}
