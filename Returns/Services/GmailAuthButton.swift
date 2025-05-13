// GmailAuthButton.swift
import SwiftUI
import AuthenticationServices

struct GmailAuthButton: View {
    @StateObject private var authManager = GmailAuthManager.shared
    @State private var isAuthenticating = false
    
    var body: some View {
        Button(action: {
            authenticateWithGoogle()
        }) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.white)
                Text(authManager.isAuthenticated ? "Gmail Connected" : "Connect Gmail")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(authManager.isAuthenticated ? Color.green : Color.blue)
            .cornerRadius(10)
        }
        .disabled(isAuthenticating || authManager.isAuthenticated)
    }
    
    private func authenticateWithGoogle() {
        isAuthenticating = true
        
        let session = ASWebAuthenticationSession(
            url: authManager.authURL,
            callbackURLScheme: "com.jstick.Returns" // Replace with your URL scheme
        ) { callbackURL, error in
            isAuthenticating = false
            
            if let error = error {
                print("Authentication error: \(error.localizedDescription)")
                return
            }
            
            guard let callbackURL = callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value
            else {
                print("Invalid callback URL")
                return
            }
            
            authManager.exchangeCodeForTokens(code: code)
        }
        
        // Setting presentation context
        session.presentationContextProvider = FindPresentationContext.shared
        session.prefersEphemeralWebBrowserSession = true
        
        // Start the session
        session.start()
    }
}

// A simple class to provide the presentation context
class FindPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = FindPresentationContext()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Find the window to present from
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
