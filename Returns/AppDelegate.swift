//
//  AppDelegate.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // In AppDelegate.swift or ReturnsApp.swift init
        print("All Info.plist keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "none")")
        print("Shippo API Key: \(Bundle.main.object(forInfoDictionaryKey: "ShippoAPIKey") ?? "not found")")
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Handle URL scheme callback for OAuth
       func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
           // Print the URL for debugging
           print("App opened with URL: \(url.absoluteString)")
           
           // The actual handling of the OAuth callback URL will be done by ASWebAuthenticationSession
           // This method just needs to return true to indicate that your app handled the URL
           return true
       }
    
    // This method will be called when a notification is received while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // This method will be called when a user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle the notification tap if needed
        completionHandler()
    }
    
}

