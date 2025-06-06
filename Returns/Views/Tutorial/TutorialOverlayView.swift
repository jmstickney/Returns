//
//  TutorialOverlay.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/21/25.
//

import SwiftUI

struct TutorialOverlay: View {
    @ObservedObject var tutorialManager: TutorialManager
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Tutorial content card
                VStack(spacing: 20) {
                    Text(tutorialManager.currentTutorialStep.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(tutorialManager.currentTutorialStep.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Show content for button highlighting steps
                    if tutorialManager.currentTutorialStep == .addReturn {
                        VStack(spacing: 12) {
                            Button(tutorialManager.currentTutorialStep.buttonText) {
                                tutorialManager.nextStep()
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                        }
                    } else if tutorialManager.currentTutorialStep == .connectGmail {
                        VStack(spacing: 12) {
                            Button(tutorialManager.currentTutorialStep.buttonText) {
                                tutorialManager.nextStep()
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                        }
                    } else {
                        // Regular buttons for welcome and complete steps
                        HStack(spacing: 20) {
                            if tutorialManager.currentStep > 0 && tutorialManager.currentTutorialStep != .complete {
                                Button("Skip Tutorial") {
                                    tutorialManager.skipTutorial()
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Button(tutorialManager.currentTutorialStep.buttonText) {
                                tutorialManager.nextStep()
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                        }
                    }
                }
                .padding(30)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
        .animation(.easeInOut, value: tutorialManager.currentStep)
    }
}
