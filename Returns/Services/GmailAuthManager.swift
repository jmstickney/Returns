// GmailAuthManager.swift (updated for iOS without client secret)
import Foundation
import SwiftUI
import Combine
import AuthenticationServices

class GmailAuthManager: ObservableObject {
    static let shared = GmailAuthManager()
    
    // MARK: - Properties
    private let clientID = "753855193871-7uisddn9vmfnqvs0qfqj3s90lr3u8gvr.apps.googleusercontent.com" // Replace with your Google Client ID
    private let redirectURI = "com.jstick.Returns:/oauth2callback" // Must match URL scheme
    private let scope = "https://www.googleapis.com/auth/gmail.readonly"
    
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?
    
    private let keychain = KeychainManager.shared
    private var refreshTokenCancellable: AnyCancellable?
    
    var authURL: URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    // Rest of your class implementation stays the same
    private init() {
        loadTokensFromKeychain()
        setupTokenRefresh()
    }
    
    // MARK: - Public Methods
    func startAuthentication() {
        // The actual authentication happens in GmailAuthButton's sheet
    }
    
    func exchangeCodeForTokens(code: String) {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // For iOS, we only need client_id, not client_secret
        let parameters: [String: String] = [
            "client_id": clientID,
            "code": code,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                print("Token exchange error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.handleTokenResponse(tokenResponse)
            } catch {
                print("Failed to decode token response: \(error)")
            }
        }.resume()
    }
    
    func refreshTokenIfNeeded() -> AnyPublisher<Bool, Error> {
        guard let refreshToken = refreshToken else {
            return Fail(error: NSError(domain: "GmailAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "No refresh token"]))
                .eraseToAnyPublisher()
        }
        
        // If token is still valid, return immediately
        if let expirationDate = tokenExpirationDate, expirationDate > Date() {
            return Just(true)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // For iOS, we only need client_id, not client_secret for refresh token too
        let parameters: [String: String] = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .map { [weak self] tokenResponse -> Bool in
                self?.handleTokenResponse(tokenResponse)
                return true
            }
            .eraseToAnyPublisher()
    }
    
    // Add this method to your GmailAuthManager class
    func getValidToken() -> AnyPublisher<String, Error> {
        // If we have a valid token, return it immediately
        if let token = accessToken,
           let expirationDate = tokenExpirationDate,
           expirationDate > Date() {
            return Just(token)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Otherwise, try to refresh the token
        return refreshTokenIfNeeded()
            .flatMap { [weak self] _ -> AnyPublisher<String, Error> in
                guard let self = self, let token = self.accessToken else {
                    return Fail(error: NSError(domain: "GmailAuth", code: 3,
                                               userInfo: [NSLocalizedDescriptionKey: "No access token after refresh"]))
                        .eraseToAnyPublisher()
                }
                return Just(token)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func logout() {
            accessToken = nil
            refreshToken = nil
            tokenExpirationDate = nil
            userEmail = nil
            isAuthenticated = false
            
            keychain.deleteToken(forKey: "gmail_access_token")
            keychain.deleteToken(forKey: "gmail_refresh_token")
            keychain.deleteToken(forKey: "gmail_token_expiration")
            keychain.deleteToken(forKey: "gmail_user_email")
        }
        
        // MARK: - Private Methods
        private func handleTokenResponse(_ response: TokenResponse) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.accessToken = response.accessToken
                
                // Only update refresh token if we received a new one
                if let newRefreshToken = response.refreshToken {
                    self.refreshToken = newRefreshToken
                    self.keychain.saveToken(newRefreshToken, forKey: "gmail_refresh_token")
                }
                
                // Calculate expiration date
                if let expiresIn = response.expiresIn {
                    self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                    self.keychain.saveToken(self.tokenExpirationDate!.timeIntervalSince1970.description, forKey: "gmail_token_expiration")
                }
                
                self.keychain.saveToken(response.accessToken, forKey: "gmail_access_token")
                self.isAuthenticated = true
                
                // Fetch user email
                self.fetchUserProfile()
            }
        }
        
        private func fetchUserProfile() {
            guard let accessToken = accessToken else { return }
            
            let profileURL = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile")!
            var request = URLRequest(url: profileURL)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let data = data, error == nil else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let email = json["emailAddress"] as? String {
                        DispatchQueue.main.async {
                            self?.userEmail = email
                            self?.keychain.saveToken(email, forKey: "gmail_user_email")
                        }
                    }
                } catch {
                    print("Failed to parse user profile: \(error)")
                }
            }.resume()
        }
        
        private func loadTokensFromKeychain() {
            if let accessToken = keychain.getToken(forKey: "gmail_access_token") {
                self.accessToken = accessToken
            }
            
            if let refreshToken = keychain.getToken(forKey: "gmail_refresh_token") {
                self.refreshToken = refreshToken
            }
            
            if let expirationString = keychain.getToken(forKey: "gmail_token_expiration"),
               let expirationTimeInterval = Double(expirationString) {
                self.tokenExpirationDate = Date(timeIntervalSince1970: expirationTimeInterval)
            }
            
            if let email = keychain.getToken(forKey: "gmail_user_email") {
                self.userEmail = email
            }
            
            // Check if we have valid tokens
            if refreshToken != nil && (tokenExpirationDate == nil || tokenExpirationDate! > Date()) {
                isAuthenticated = true
            }
        }
        
        private func setupTokenRefresh() {
            // Set up a timer to refresh the token before it expires
            refreshTokenCancellable = Timer.publish(every: 30 * 60, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self, self.isAuthenticated else { return }
                    _ = self.refreshTokenIfNeeded()
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                }
        }
    }

    // MARK: - Supporting Types
    struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int?
        let refreshToken: String?
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }
