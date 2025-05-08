//
//  GmailAuthButton.swift
//  Returns
//
//  Created by Jonathan Stickney on 4/26/25.
//


//import SwiftUI
//import AuthenticationServices
//
//struct GmailAuthButton: View {
//    @State private var authSession: ASWebAuthenticationSession?
//
//    var body: some View {
//        Button("Connect Gmail") {
//            let clientID = "YOUR_GOOGLE_CLIENT_ID"
//            let redirectURI = "com.yourapp:/oauth2callback"
//            let scope = "https://www.googleapis.com/auth/gmail.readonly"
//            let authURL = URL(string:
//                "https://accounts.google.com/o/oauth2/v2/auth" +
//                "?client_id=\(clientID)" +
//                "&redirect_uri=\(redirectURI)" +
//                "&response_type=code" +
//                "&scope=\(scope)"
//            )!
//
//            authSession = ASWebAuthenticationSession(url: authURL,
//                                                     callbackURLScheme: "com.yourapp") { callbackURL, error in
//                guard let callback = callbackURL,
//                      let code = URLComponents(string: callback.absoluteString)?
//                        .queryItems?
//                        .first(where: { $0.name == "code" })?.value else {
//                    print("OAuth failed: \(error?.localizedDescription ?? "unknown")")
//                    return
//                }
//                // Send `code` to backend to exchange for tokens
//                Task {
//                    await Backend.exchangeAuthCodeForTokens(code)
//                }
//            }
//            authSession?.presentationContextProvider = /* your provider */
//            authSession?.start()
//        }
//    }
//}
