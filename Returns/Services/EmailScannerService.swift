//
//  EmailScannerService.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/9/25.
//


// EmailScannerService.swift
import Foundation
import Combine

class EmailScannerService {
    static let shared = EmailScannerService()
    
    private let authManager = GmailAuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    //private var isFirstScan = true
    
    private init() {}
    
    // MARK: - Public Methods
    
    func scanEmailsForReturns() -> AnyPublisher<[PotentialReturn], Error> {
        
        return authManager.getValidToken()
            .flatMap { token -> AnyPublisher<[GmailMessage], Error> in
                return self.searchEmails(withToken: token)
            }
            .flatMap { messages -> AnyPublisher<[PotentialReturn], Error> in
                return self.processMessages(messages)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func logDebug(_ message: String) {
        print("📧 [EmailScanner] \(message)")
    }
    
    private func searchEmails(withToken token: String) -> AnyPublisher<[GmailMessage], Error> {
        let query = "subject:(return) newer_than:100d"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/messages?q=\(encodedQuery)") else {
            return Fail(error: NSError(domain: "EmailScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GmailMessageListResponse.self, decoder: JSONDecoder())
            .flatMap { messageList -> AnyPublisher<[GmailMessage], Error> in
                guard let messageIds = messageList.messages else {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                let messagePublishers = messageIds.map { messageId in
                    self.fetchMessageDetails(messageId: messageId.id, token: token)
                }
                
                return Publishers.MergeMany(messagePublishers)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchMessageDetails(messageId: String, token: String) -> AnyPublisher<GmailMessage, Error> {
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/messages/\(messageId)?format=full") else {
            return Fail(error: NSError(domain: "EmailScanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid message URL"]))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GmailMessage.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func processMessages(_ messages: [GmailMessage]) -> AnyPublisher<[PotentialReturn], Error> {
        // Process messages to extract return information
        let potentialReturns = messages.compactMap { message -> PotentialReturn? in
            // Extract subject
            let subject = message.payload.headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? ""
            
            // Get sender
            let from = message.payload.headers.first(where: { $0.name.lowercased() == "from" })?.value ?? ""
            let retailer = extractRetailerName(from: from)
            
            // Get message body
            let body = extractEmailBody(message.payload)
            
            // Look for return-related content
            guard isReturnEmail(subject: subject, body: body) else { return nil }
            
            // Use the internalDate if available
            let emailDate: Date
            if let internalDate = message.internalDateAsDate {
                emailDate = internalDate
                print("📅 Using internalDate: \(emailDate)")
            } else {
                // Fall back to header date
                let emailDateHeader = message.payload.headers.first(where: { $0.name.lowercased() == "date" })?.value ?? ""
                emailDate = parseEmailDate(emailDateHeader) ?? Date()
                print("📅 Using header date: \(emailDate)")
            }
            
            // Try to extract product name and amount
            let productName = extractProductName(from: subject, body: body) ?? "Unknown Product"
            let amount = extractRefundAmount(from: body) ?? 0.0
            
            return PotentialReturn(
                id: UUID(),
                emailId: message.id,
                productName: productName,
                retailer: retailer,
                emailDate: emailDate,
                refundAmount: amount,
                emailSubject: subject,
                emailSnippet: message.snippet
            )
        }
        
        return Just(potentialReturns)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // Helper methods for parsing email content
    
    private func extractEmailBody(_ payload: GmailMessagePayload) -> String {
        // First try to get plain text part
        if let textPart = findPartByMimeType(payload: payload, mimeType: "text/plain") {
            if let data = textPart.body.data {
                let decodedData = Data(base64Encoded: data.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"))
                if let decodedString = decodedData.flatMap({ String(data: $0, encoding: .utf8) }) {
                    return decodedString
                }
            }
        }
        
        // Then try HTML part
        if let htmlPart = findPartByMimeType(payload: payload, mimeType: "text/html") {
            if let data = htmlPart.body.data {
                let decodedData = Data(base64Encoded: data.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"))
                if let decodedString = decodedData.flatMap({ String(data: $0, encoding: .utf8) }) {
                    // Simple HTML to text conversion
                    return decodedString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                }
            }
        }
        
        // If no parts, check if the payload itself has a body
        if let data = payload.body.data {
            let decodedData = Data(base64Encoded: data.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"))
            if let decodedString = decodedData.flatMap({ String(data: $0, encoding: .utf8) }) {
                return decodedString
            }
        }
        
        return ""
    }
    
    private func findPartByMimeType(payload: GmailMessagePayload, mimeType: String) -> GmailMessagePart? {
        if payload.mimeType == mimeType {
            return payload
        }
        
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == mimeType {
                    return part
                }
                
                if let nestedPart = findPartByMimeType(payload: part, mimeType: mimeType) {
                    return nestedPart
                }
            }
        }
        
        return nil
    }
    
    private func isReturnEmail(subject: String, body: String) -> Bool {
        let returnKeywords = ["return", "refund", "money back", "rma", "return merchandise",
                              "shipped", "order", "purchase", "receipt"]
        
        self.logDebug("Analyzing email: \(subject)")
        
        let subjectLower = subject.lowercased()
        let bodyLower = body.lowercased()
        
        // Check if any return keywords are in the subject or body
        for keyword in returnKeywords {
            if subjectLower.contains(keyword) || bodyLower.contains(keyword) {
                self.logDebug("✓ Found keyword: \(keyword)")
                return true
            }
        }
        
        self.logDebug("✗ No relevant keywords found in email")
        return false
    }
    
    private func extractRetailerName(from emailAddress: String) -> String {
        // Gmail formats "From" headers typically as: "Display Name <email@domain.com>"
        
        self.logDebug("Extracting retailer from: \(emailAddress)")
        
        // First try to extract the display name part (most reliable)
        if let displayNameEndIndex = emailAddress.firstIndex(of: "<") {
            let displayName = emailAddress[..<displayNameEndIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if !displayName.isEmpty {
                self.logDebug("Found display name: \(displayName)")
                
                // Clean up common suffixes and prefixes
                let cleanName = cleanupRetailerName(displayName)
                
                // If we have a meaningful display name after cleanup, use it
                if !cleanName.isEmpty && cleanName.count > 1 {
                    return cleanName
                }
            }
        }
        
        // Fallback: Try to extract from the email domain
        if let emailStart = emailAddress.firstIndex(of: "<"),
           let atIndex = emailAddress[emailStart...].firstIndex(of: "@"),
           let dotIndex = emailAddress[atIndex...].firstIndex(of: ".") {
            
            let domainStart = emailAddress.index(after: atIndex)
            let domainName = emailAddress[domainStart..<dotIndex]
            let cleanDomain = cleanupRetailerName(String(domainName))
            
            self.logDebug("Extracted domain name: \(cleanDomain)")
            return cleanDomain
        }
        
        // Final fallback - just get anything after @ if present
        if let atIndex = emailAddress.firstIndex(of: "@") {
            let domainPart = emailAddress[emailAddress.index(after: atIndex)...]
            if let dotIndex = domainPart.firstIndex(of: ".") {
                let company = domainPart[..<dotIndex]
                return cleanupRetailerName(String(company))
            }
            return cleanupRetailerName(String(domainPart))
        }
        
        return "Unknown Retailer"
    }

    private func cleanupRetailerName(_ name: String) -> String {
        var result = name
        
        // Common suffixes to remove
        let suffixesToRemove = [
            " Inc", " LLC", " Ltd", " Team", " Support", " Customer Service",
            " Store", " Shop", " US", " USA", " NA", " Help", " Orders",
            " Receipts", " Order Confirmation", " noreply", " no-reply",
            " Notifications", " Info", " Mail"
        ]
        
        // Common prefixes to remove
        let prefixesToRemove = [
            "The ", "Order from ", "Your Order from ", "Receipt from ",
            "orders@", "support@", "noreply@", "no-reply@", "info@",
            "customerservice@", "notifications@"
        ]
        
        // Remove suffixes
        for suffix in suffixesToRemove {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
            }
        }
        
        // Remove prefixes
        for prefix in prefixesToRemove {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
            }
        }
        
        // Clean up special characters and extra spaces
        result = result.replacingOccurrences(of: "\"", with: "")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize the first letter of each word
        let words = result.components(separatedBy: " ")
        result = words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
        
        return result
    }
    
    private func extractProductName(from subject: String, body: String) -> String? {
        // First, check if product name is in the subject
        let subjectPatterns = [
            "return.*?for\\s+(.+?)\\s+confirmed",
            "your\\s+(.+?)\\s+return",
            "return\\s+confirmation\\s+for\\s+(.+)",
            "refund\\s+for\\s+(.+)"
        ]
        
        for pattern in subjectPatterns {
            if let range = subject.range(of: pattern, options: .regularExpression) {
                let match = subject[range]
                // Extract the capture group
                if let captureRange = match.range(of: "\\((.+?)\\)", options: .regularExpression) {
                    return String(subject[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Then check for order/item numbers in the body
        let bodyPatterns = [
            "item[:\\s]+([\\w\\d-]+)",
            "product[:\\s]+([\\w\\d-]+)",
            "order\\s+item[:\\s]+(.+?)(\\n|\\.|$)"
        ]
        
        for pattern in bodyPatterns {
            if let range = body.range(of: pattern, options: .regularExpression) {
                let match = body[range]
                if let captureRange = match.range(of: "\\((.+?)\\)", options: .regularExpression) {
                    return String(body[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // If no specific product name found
        return nil
    }
    
    private func extractRefundAmount(from body: String) -> Double? {
        // Look for currency patterns like $XX.XX
        let patterns = [
            "refund\\s+amount[:\\s]+[$]?(\\d+\\.\\d{2})",
            "amount[:\\s]+[$]?(\\d+\\.\\d{2})",
            "[$](\\d+\\.\\d{2})\\s+refund",
            "[$](\\d+\\.\\d{2})"
        ]
        
        for pattern in patterns {
            if let range = body.range(of: pattern, options: .regularExpression) {
                let match = body[range]
                
                if let captureRange = match.range(of: "(\\d+\\.\\d{2})", options: .regularExpression) {
                    let amountString = String(body[captureRange])
                    return Double(amountString)
                }
            }
        }
        
        return nil
    }
    
    
        // EmailScannerService.swift (continued)
            private func parseEmailDate(_ dateString: String) -> Date? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try alternative formats
                dateFormatter.dateFormat = "dd MMM yyyy HH:mm:ss Z"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try one more format
                dateFormatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                return nil
            }
    
        }



        // MARK: - Supporting Models

        struct GmailMessageListResponse: Decodable {
            let messages: [GmailMessageId]?
            let nextPageToken: String?
        }

        struct GmailMessageId: Decodable {
            let id: String
            let threadId: String
        }

        struct GmailMessage: Decodable {
            let id: String
            let threadId: String
            let labelIds: [String]?
            let snippet: String
            let payload: GmailMessagePayload
            let sizeEstimate: Int
            let historyId: String
            let internalDate: String?
            
            // Add a computed property to convert the string to a Date
                var internalDateAsDate: Date? {
                    guard let internalDateStr = internalDate,
                          let internalDateMillis = Int64(internalDateStr) else {
                        return nil
                    }
                    return Date(timeIntervalSince1970: Double(internalDateMillis) / 1000.0)
                }
        }

        struct GmailMessagePayload: Decodable {
            let partId: String?
            let mimeType: String
            let filename: String?
            let headers: [GmailMessageHeader]
            let body: GmailMessageBody
            let parts: [GmailMessagePart]?
        }

        typealias GmailMessagePart = GmailMessagePayload

        struct GmailMessageHeader: Decodable {
            let name: String
            let value: String
        }

        struct GmailMessageBody: Decodable {
            let attachmentId: String?
            let size: Int
            let data: String?
        }

        struct PotentialReturn {
            let id: UUID
            let emailId: String
            let productName: String
            let retailer: String
            let emailDate: Date
            //let returnDate: Date
            let refundAmount: Double
            let emailSubject: String
            let emailSnippet: String
        }
