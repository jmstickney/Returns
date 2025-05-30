//
//  TutorialManager.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/21/25.
//

import SwiftUI

class TutorialManager: ObservableObject {
    @Published var showTutorial = false
    @Published var currentStep = 0
    @Published var tutorialCompleted = false
    
    enum TutorialStep: Int, CaseIterable {
        case welcome = 0
        case addReturn = 1
        case connectGmail = 2
        case complete = 3
        
        var title: String {
            switch self {
            case .welcome:
                return "Welcome to Returns!"
            case .addReturn:
                return "Add Your Returns"
            case .connectGmail:
                return "Connect Your Email"
            case .complete:
                return "You're All Set!"
            }
        }
        
        var description: String {
            switch self {
            case .welcome:
                return "Let's show you the two main ways to track your returns."
            case .addReturn:
                return "Tap 'Add Return' in the top right to manually add items you're returning to stores."
            case .connectGmail:
                return "Or connect Gmail to automatically find returns in your email inbox."
            case .complete:
                return "That's it! Start tracking your returns and never lose money again."
            }
        }
        
        var buttonText: String {
            switch self {
            case .welcome:
                return "Show Me"
            case .addReturn, .connectGmail:
                return "Got It"
            case .complete:
                return "Start Using App"
            }
        }
    }
    
    var currentTutorialStep: TutorialStep {
        TutorialStep(rawValue: currentStep) ?? .welcome
    }
    
    func startTutorialAfterOnboarding() {
        // Only start if onboarding is complete and tutorial hasn't been done
        let onboardingComplete = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let tutorialComplete = UserDefaults.standard.bool(forKey: "tutorial_completed")
        
        print("🎯 Tutorial Check - Onboarding Complete: \(onboardingComplete), Tutorial Complete: \(tutorialComplete)")
        
        if onboardingComplete && !tutorialComplete {
            currentStep = 0
            showTutorial = true
            print("✅ Starting tutorial")
        } else {
            print("❌ Tutorial not started - Onboarding: \(onboardingComplete ? "✅" : "❌"), Tutorial: \(tutorialComplete ? "already done" : "not done")")
        }
    }
    
    func startTutorialWhenReady() {
        // This method can be called from the onboarding completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startTutorialAfterOnboarding()
        }
    }
    
    func nextStep() {
        if currentStep < TutorialStep.allCases.count - 1 {
            currentStep += 1
        } else {
            completeTutorial()
        }
    }
    
    func skipTutorial() {
        completeTutorial()
    }
    
    private func completeTutorial() {
        showTutorial = false
        tutorialCompleted = true
        UserDefaults.standard.set(true, forKey: "tutorial_completed")
    }
}
