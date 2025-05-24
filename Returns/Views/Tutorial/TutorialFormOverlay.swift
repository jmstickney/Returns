//
//  TutorialFormOverlay.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/24/25.
//
import SwiftUI

struct TutorialFormOverlay: View {
    @ObservedObject var tutorialManager: TutorialManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Fill Out Your Return Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Enter the product name, retailer, refund amount, and any other details about your return.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Got it!") {
                        tutorialManager.nextStep()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                .padding(30)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
    }
}

struct ReturnsListView_Previews: PreviewProvider {
    static var previews: some View {
        ReturnsListView()
    }
}
