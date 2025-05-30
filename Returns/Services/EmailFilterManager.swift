//
//  EmailFilterManager.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/30/25.
//


//
//  EmailFilterManager.swift
//  Returns
//
//  Simple email filtering using UserDefaults
//

import Foundation

class EmailFilterManager {
    static let shared = EmailFilterManager()
    private let hiddenEmailsKey = "hiddenEmails"
    
    private init() {}
    
    // Hide an email from future scans
    func hideEmail(_ emailId: String) {
        var hiddenEmails = getHiddenEmails()
        hiddenEmails.insert(emailId)
        UserDefaults.standard.set(Array(hiddenEmails), forKey: hiddenEmailsKey)
        print("📧 Hidden email: \(emailId)")
    }
    
    // Unhide a specific email
    func unhideEmail(_ emailId: String) {
        var hiddenEmails = getHiddenEmails()
        hiddenEmails.remove(emailId)
        UserDefaults.standard.set(Array(hiddenEmails), forKey: hiddenEmailsKey)
        print("📧 Unhidden email: \(emailId)")
    }
    
    // Check if an email is hidden
    func isEmailHidden(_ emailId: String) -> Bool {
        return getHiddenEmails().contains(emailId)
    }
    
    // Get all hidden email IDs
    func getHiddenEmailIds() -> Set<String> {
        return getHiddenEmails()
    }
    
    // Get count of hidden emails
    func hiddenEmailCount() -> Int {
        return getHiddenEmails().count
    }
    
    // Clear all hidden emails
    func clearAllHiddenEmails() {
        UserDefaults.standard.removeObject(forKey: hiddenEmailsKey)
        print("📧 Cleared all hidden emails")
    }
    
    // Private helper to get hidden emails set
    private func getHiddenEmails() -> Set<String> {
        let array = UserDefaults.standard.array(forKey: hiddenEmailsKey) as? [String] ?? []
        return Set(array)
    }
}